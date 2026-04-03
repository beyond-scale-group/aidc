#!/usr/bin/env bash
# AIDC Onboarding Script
# Run this locally to configure your Clever Cloud deployment.
#
# Usage:
#   bash scripts/onboard.sh              # interactive menu
#   bash scripts/onboard.sh --all        # configure everything
#   bash scripts/onboard.sh --slack --gh # configure specific integrations
#
# Flags: --anthropic --gh --gws --gcp --agent-auth --telegram --slack --discord --all
set -euo pipefail

BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RESET="\033[0m"

info()    { echo -e "${CYAN}→${RESET} $*"; }
success() { echo -e "${GREEN}✓${RESET} $*"; }
warn()    { echo -e "${YELLOW}!${RESET} $*"; }
header()  { echo -e "\n${BOLD}$*${RESET}"; }
ask()     { echo -en "${BOLD}$1${RESET} "; }

# ─── Parse CLI flags ──────────────────────────────────────────────────────────

DO_ANTHROPIC=false
DO_GH=false
DO_GWS=false
DO_GCP=false
DO_AGENT_AUTH=false
DO_TELEGRAM=false
DO_SLACK=false
DO_DISCORD=false
INTERACTIVE=true

for arg in "$@"; do
  case "$arg" in
    -h|--help)
      echo "Usage: bash scripts/onboard.sh [flags]"
      echo
      echo "Without flags, runs an interactive menu to pick what to configure."
      echo
      echo "Flags:"
      echo "  --all         Configure everything"
      echo "  --anthropic   Anthropic API key"
      echo "  --gh          GitHub CLI (gh)"
      echo "  --gws         Google Workspace (gws)"
      echo "  --gcp         Google Cloud (gcloud service account)"
      echo "  --agent-auth  Per-agent Google + GitHub credentials"
      echo "  --telegram    Donna → Telegram"
      echo "  --slack       Donna → Slack"
      echo "  --discord     Donna → Discord"
      echo "  -h, --help    Show this help"
      exit 0 ;;
    --all)        DO_ANTHROPIC=true; DO_GH=true; DO_GWS=true; DO_GCP=true; DO_AGENT_AUTH=true; DO_TELEGRAM=true; DO_SLACK=true; DO_DISCORD=true; INTERACTIVE=false ;;
    --anthropic)  DO_ANTHROPIC=true;  INTERACTIVE=false ;;
    --gh)         DO_GH=true;         INTERACTIVE=false ;;
    --gws)        DO_GWS=true;        INTERACTIVE=false ;;
    --gcp)        DO_GCP=true;        INTERACTIVE=false ;;
    --agent-auth) DO_AGENT_AUTH=true; INTERACTIVE=false ;;
    --telegram)   DO_TELEGRAM=true;   INTERACTIVE=false ;;
    --slack)      DO_SLACK=true;      INTERACTIVE=false ;;
    --discord)    DO_DISCORD=true;    INTERACTIVE=false ;;
    *) echo "Unknown flag: $arg. Run with -h for help."; exit 1 ;;
  esac
done

# ─── Prerequisites ────────────────────────────────────────────────────────────

header "Checking prerequisites…"

for cmd in clever git curl base64; do
  if command -v "$cmd" &>/dev/null; then
    success "$cmd found"
  else
    echo "✗ $cmd is required but not installed. Aborting."
    exit 1
  fi
done

# ─── Clever Cloud link ────────────────────────────────────────────────────────

header "Clever Cloud app"

if clever status &>/dev/null 2>&1; then
  APP_NAME=$(clever status 2>/dev/null | head -1 | awk '{print $1}')
  success "Already linked to app: $APP_NAME"
else
  warn "No Clever Cloud app linked. Make sure you run 'clever link' or 'tofu apply' first."
  exit 1
fi

# ─── Interactive menu ─────────────────────────────────────────────────────────

if [[ "$INTERACTIVE" == true ]]; then
  header "What would you like to configure?"
  echo
  echo "  a  Anthropic API key  (required to run agents)"
  echo "  g  GitHub CLI (gh)    (manage repos, issues, PRs)"
  echo "  w  Google Workspace   (Gmail, Calendar, Drive…)"
  echo "  c  Google Cloud       (GCP service account)"
  echo "  x  Agent credentials  (per-agent Google + GitHub auth)"
  echo "  t  Telegram           (reach Donna via Telegram bot)"
  echo "  s  Slack              (reach Donna via Slack)"
  echo "  d  Discord            (reach Donna via Discord)"
  echo
  ask "Enter letters separated by spaces (e.g. 'a s' or 'all') [default: a]:"
  read -r SELECTION
  SELECTION="${SELECTION:-a}"

  if [[ "$SELECTION" == "all" ]]; then
    DO_ANTHROPIC=true; DO_GH=true; DO_GWS=true; DO_GCP=true; DO_AGENT_AUTH=true
    DO_TELEGRAM=true; DO_SLACK=true; DO_DISCORD=true
  else
    [[ "$SELECTION" == *a* ]] && DO_ANTHROPIC=true
    [[ "$SELECTION" == *g* ]] && DO_GH=true
    [[ "$SELECTION" == *w* ]] && DO_GWS=true
    [[ "$SELECTION" == *c* ]] && DO_GCP=true
    [[ "$SELECTION" == *x* ]] && DO_AGENT_AUTH=true
    [[ "$SELECTION" == *t* ]] && DO_TELEGRAM=true
    [[ "$SELECTION" == *s* ]] && DO_SLACK=true
    [[ "$SELECTION" == *d* ]] && DO_DISCORD=true
  fi
fi

# ─── Anthropic API key ────────────────────────────────────────────────────────

if [[ "$DO_ANTHROPIC" == true ]]; then
  header "Anthropic API key"

  CURRENT=$(clever env get ANTHROPIC_API_KEY 2>/dev/null | grep ANTHROPIC_API_KEY | awk -F= '{print $2}' || true)
  if [[ -n "${CURRENT:-}" ]]; then
    success "ANTHROPIC_API_KEY already set"
  else
    ask "Anthropic API key (sk-ant-…):"
    read -rs ANTHROPIC_API_KEY
    echo
    clever env set ANTHROPIC_API_KEY "$ANTHROPIC_API_KEY"
    success "ANTHROPIC_API_KEY set"
  fi
fi

# ─── GitHub CLI ───────────────────────────────────────────────────────────────

if [[ "$DO_GH" == true ]]; then
  header "GitHub CLI (gh)"
  echo "Allows agents to create/manage issues, PRs, and repos."
  echo "Generate a token at: https://github.com/settings/tokens"
  echo "Recommended scopes: repo, read:org, workflow"
  echo

  ask "GitHub Personal Access Token:"
  read -rs GH_TOKEN
  echo

  if [[ -n "${GH_TOKEN:-}" ]]; then
    clever env set GH_TOKEN "$GH_TOKEN"
    success "GH_TOKEN set — agents can now use 'gh' CLI"
  else
    warn "Skipped — agents won't have GitHub CLI access"
  fi
fi

# ─── Google Workspace ─────────────────────────────────────────────────────────

if [[ "$DO_GWS" == true ]]; then
  header "Google Workspace (gws)"
  echo "Allows agents to interact with Gmail, Calendar, Drive, Sheets, Docs, etc."
  echo "Credentials are configured per-agent."
  echo

  info "Run: bash scripts/setup-agent-auth.sh <google-email> <github-user>"
  warn "Global GWS setup skipped — use setup-agent-auth.sh for each agent."
fi

# ─── Google Cloud ─────────────────────────────────────────────────────────────

if [[ "$DO_GCP" == true ]]; then
  header "Google Cloud (gcloud)"
  echo "Allows agents to interact with GCP services."
  echo "Create a service account at: https://console.cloud.google.com/iam-admin/serviceaccounts"
  echo "Then: Keys → Add Key → JSON → download the file"
  echo

  ask "Path to service account JSON file (leave blank to skip):"
  read -r GCP_KEY_PATH

  if [[ -n "${GCP_KEY_PATH:-}" ]]; then
    if [[ ! -f "$GCP_KEY_PATH" ]]; then
      warn "File not found: $GCP_KEY_PATH — skipping GCP setup"
    else
      GCP_SA_KEY=$(base64 < "$GCP_KEY_PATH" | tr -d '\n')
      GCP_PROJECT_ID=$(python3 -c "import json,sys; print(json.load(open('$GCP_KEY_PATH'))['project_id'])" 2>/dev/null || true)

      clever env set GCP_SA_KEY "$GCP_SA_KEY"
      success "GCP_SA_KEY set (base64-encoded)"

      if [[ -n "${GCP_PROJECT_ID:-}" ]]; then
        clever env set GCP_PROJECT_ID "$GCP_PROJECT_ID"
        success "GCP_PROJECT_ID set to: $GCP_PROJECT_ID"
      else
        ask "GCP Project ID (from your GCP console):"
        read -r GCP_PROJECT_ID
        clever env set GCP_PROJECT_ID "$GCP_PROJECT_ID"
        success "GCP_PROJECT_ID set"
      fi
    fi
  else
    warn "Skipped — agents won't have Google Cloud CLI access"
  fi
fi

# ─── Agent credentials ────────────────────────────────────────────────────────

if [[ "$DO_AGENT_AUTH" == true ]]; then
  header "Agent credentials (Google + GitHub)"
  echo "Run setup-agent-auth.sh for each agent that needs Google/GitHub access."
  echo

  bash "$(dirname "$0")/setup-agent-auth.sh"
fi

# ─── Hooks ───────────────────────────────────────────────────────────────────

header "Wiring CLI installation hooks…"

clever env set CC_PRE_BUILD_HOOK "bash scripts/install-tools.sh"
success "CC_PRE_BUILD_HOOK → scripts/install-tools.sh"

clever env set CC_PRE_RUN_HOOK "bash scripts/startup.sh"
success "CC_PRE_RUN_HOOK → scripts/startup.sh"

# ─── Donna — Telegram ────────────────────────────────────────────────────────

if [[ "$DO_TELEGRAM" == true ]]; then
  header "Donna — Telegram"
  echo "  1. Message @BotFather → /newbot → copy the token"
  echo "  2. Get your user ID from @userinfobot"
  echo

  ask "Telegram bot token:"
  read -rs TELEGRAM_BOT_TOKEN
  echo

  if [[ -n "${TELEGRAM_BOT_TOKEN:-}" ]]; then
    clever env set TELEGRAM_BOT_TOKEN "$TELEGRAM_BOT_TOKEN"
    ask "Restrict to specific Telegram user IDs? (leave blank to allow anyone who messages the bot):"
    read -r TELEGRAM_ALLOWED_USERS
    echo
    [[ -n "${TELEGRAM_ALLOWED_USERS:-}" ]] && clever env set TELEGRAM_ALLOWED_USERS "$TELEGRAM_ALLOWED_USERS"
    success "Telegram configured — Donna will be reachable via bot"
  else
    warn "Skipped — token left blank"
  fi
fi

# ─── Donna — Slack ────────────────────────────────────────────────────────────

if [[ "$DO_SLACK" == true ]]; then
  header "Donna — Slack"
  echo "Create your app at api.slack.com/apps, then:"
  echo "  • Bot token (xoxb-…)  — Settings → Install App"
  echo "  • App token (xapp-…)  — Settings → Socket Mode (enable it first)"
  echo "  Required OAuth scopes: chat:write, channels:history, im:history, app_mention"
  echo

  ask "Slack bot token (xoxb-…):"
  read -rs SLACK_BOT_TOKEN
  echo

  if [[ -n "${SLACK_BOT_TOKEN:-}" ]]; then
    clever env set SLACK_BOT_TOKEN "$SLACK_BOT_TOKEN"

    ask "Slack app-level token (xapp-…):"
    read -rs SLACK_APP_TOKEN
    echo
    [[ -n "${SLACK_APP_TOKEN:-}" ]] && clever env set SLACK_APP_TOKEN "$SLACK_APP_TOKEN"

    ask "Restrict to specific Slack member IDs? (leave blank to allow all workspace members):"
    read -r SLACK_ALLOWED_USERS
    echo
    [[ -n "${SLACK_ALLOWED_USERS:-}" ]] && clever env set SLACK_ALLOWED_USERS "$SLACK_ALLOWED_USERS"

    success "Slack configured — Donna will be reachable via @mention or DM"
  else
    warn "Skipped — token left blank"
  fi
fi

# ─── Donna — Discord ──────────────────────────────────────────────────────────

if [[ "$DO_DISCORD" == true ]]; then
  header "Donna — Discord"
  echo "In the Discord Developer Portal:"
  echo "  1. Create an app → Bot → Add Bot → copy token"
  echo "  2. Enable: Message Content Intent + Server Members Intent"
  echo "  3. Invite the bot with: Send Messages, Read Message History, View Channels"
  echo

  ask "Discord bot token:"
  read -rs DISCORD_BOT_TOKEN
  echo

  if [[ -n "${DISCORD_BOT_TOKEN:-}" ]]; then
    clever env set DISCORD_BOT_TOKEN "$DISCORD_BOT_TOKEN"

    ask "Restrict to specific Discord user IDs? (leave blank to allow all server members):"
    read -r DISCORD_ALLOWED_USERS
    echo
    [[ -n "${DISCORD_ALLOWED_USERS:-}" ]] && clever env set DISCORD_ALLOWED_USERS "$DISCORD_ALLOWED_USERS"

    success "Discord configured — Donna will be reachable via @mention or DM"
  else
    warn "Skipped — token left blank"
  fi
fi

# ─── Deploy ───────────────────────────────────────────────────────────────────

header "Ready to deploy"
echo
echo "Configuration complete. Summary of what was set:"
clever env 2>/dev/null | grep -E "^(GH_TOKEN|GCP_SA_KEY|GCP_PROJECT_ID|ANTHROPIC_API_KEY|CC_PRE_BUILD_HOOK|CC_PRE_RUN_HOOK|TELEGRAM_|SLACK_|DISCORD_)" | sed 's/=.*/=***/' || true
echo

ask "Deploy now? [Y/n]:"
read -r DEPLOY_NOW
DEPLOY_NOW="${DEPLOY_NOW:-Y}"

if [[ "$DEPLOY_NOW" =~ ^[Yy]$ ]]; then
  info "Stopping app for clean restart…"
  clever stop 2>/dev/null || true
  sleep 3
  clever restart
  success "Deployment triggered!"
else
  warn "Skipped deploy. Run 'clever restart' when ready."
fi

echo
success "Onboarding complete."
