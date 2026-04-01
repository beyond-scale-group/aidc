#!/usr/bin/env bash
# AIDC Onboarding Script
# Run this once locally to configure your Clever Cloud deployment.
# Prerequisites: clever (Clever Cloud CLI), git
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

# ─── Required: Anthropic API key ─────────────────────────────────────────────

header "Anthropic API key (required)"

CURRENT_ANTHROPIC=$(clever env get ANTHROPIC_API_KEY 2>/dev/null | grep ANTHROPIC_API_KEY | awk -F= '{print $2}' || true)
if [[ -n "${CURRENT_ANTHROPIC:-}" ]]; then
  success "ANTHROPIC_API_KEY already set"
else
  ask "Anthropic API key (sk-ant-…):"
  read -rs ANTHROPIC_API_KEY
  echo
  clever env set ANTHROPIC_API_KEY "$ANTHROPIC_API_KEY"
  success "ANTHROPIC_API_KEY set"
fi

# ─── Optional: GitHub CLI ─────────────────────────────────────────────────────

header "GitHub CLI (gh) — optional"
echo "Allows agents to create/manage issues, PRs, and repos."
echo "Generate a token at: https://github.com/settings/tokens"
echo "Recommended scopes: repo, read:org, workflow"
echo

ask "GitHub Personal Access Token (leave blank to skip):"
read -rs GH_TOKEN
echo

if [[ -n "${GH_TOKEN:-}" ]]; then
  clever env set GH_TOKEN "$GH_TOKEN"
  success "GH_TOKEN set — agents can now use 'gh' CLI"
else
  warn "Skipped — agents won't have GitHub CLI access"
fi

# ─── Optional: Google Cloud CLI ───────────────────────────────────────────────

header "Google Cloud CLI (gcloud) — optional"
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

# ─── Enable CLI installation at build time ────────────────────────────────────

header "Wiring CLI installation hooks…"

clever env set CC_PRE_BUILD_HOOK "bash scripts/install-tools.sh"
success "CC_PRE_BUILD_HOOK → scripts/install-tools.sh"

clever env set CC_PRE_RUN_HOOK "bash scripts/startup.sh"
success "CC_PRE_RUN_HOOK → scripts/startup.sh"

# ─── Agent credentials (optional) ────────────────────────────────────────────

header "Agent credentials (Google + GitHub)"
echo "Run setup-agent-auth.sh for each agent that needs Google/GitHub access."
echo

ask "Set up agent credentials now? [y/N]:"
read -r SETUP_AGENT
if [[ "${SETUP_AGENT:-N}" =~ ^[Yy]$ ]]; then
  bash "$(dirname "$0")/setup-agent-auth.sh"
fi

# ─── Deploy ───────────────────────────────────────────────────────────────────

header "Ready to deploy"
echo
echo "Configuration complete. Summary of what was set:"
clever env 2>/dev/null | grep -E "^(GH_TOKEN|GCP_SA_KEY|GCP_PROJECT_ID|ANTHROPIC_API_KEY|CC_PRE_BUILD_HOOK|CC_PRE_RUN_HOOK)" | sed 's/=.*/=***/' || true
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
