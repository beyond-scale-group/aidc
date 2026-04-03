#!/usr/bin/env bash
# Setup Google Workspace (gws), Google Cloud (gcloud), and GitHub credentials
# for a Paperclip agent on the FS bucket.
# Run once locally per agent after creating their accounts.
#
# Usage:
#   bash scripts/setup-agent-auth.sh                               # interactive
#   bash scripts/setup-agent-auth.sh <google-email> <github-user>  # positional
#
# Or via env vars (useful in CI or called from onboard.sh):
#   AGENT_EMAIL=donna.ai@the-shift.ai AGENT_GITHUB=donna-bsg \
#     bash scripts/setup-agent-auth.sh
#
# Prerequisites: gws, gcloud, gh, clever, curl
set -euo pipefail

BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RESET="\033[0m"

info()    { echo -e "${CYAN}→${RESET} $*"; }
success() { echo -e "${GREEN}✓${RESET} $*"; }
warn()    { echo -e "${YELLOW}!${RESET} $*"; }
ask()     { echo -en "${BOLD}$1${RESET} "; }

# ─── Prerequisites ────────────────────────────────────────────────────────────

install_if_missing() {
  local cmd="$1" brew_pkg="$2" brew_cask="${3:-}"
  if command -v "$cmd" &>/dev/null; then
    success "$cmd already installed"
    return
  fi
  if command -v brew &>/dev/null; then
    info "Installing $cmd via Homebrew…"
    if [[ -n "$brew_cask" ]]; then
      brew install --cask "$brew_cask"
    else
      brew install "$brew_pkg"
    fi
    success "$cmd installed"
  else
    warn "Homebrew not found — install $cmd manually: https://brew.sh"
    warn "Then re-run this script."
    exit 1
  fi
}

install_npm_if_missing() {
  local cmd="$1" npm_pkg="$2"
  if command -v "$cmd" &>/dev/null; then
    success "$cmd already installed"
    return
  fi
  if command -v npm &>/dev/null; then
    info "Installing $cmd via npm…"
    npm install -g "$npm_pkg"
    success "$cmd installed"
  else
    warn "npm not found — install Node.js first: https://nodejs.org"
    warn "Then re-run this script."
    exit 1
  fi
}

echo -e "\n${BOLD}── Checking prerequisites ──${RESET}"
install_npm_if_missing gws @googleworkspace/cli
install_if_missing gcloud google-cloud-sdk google-cloud-sdk
install_if_missing gh gh
install_if_missing clever clever-tools
install_if_missing curl curl

BUCKET_HOST="bucket-a99c8ef2-e7f2-4230-9ea5-69446996fe92-fsbucket.services.clever-cloud.com"
BUCKET_USER="ua99c8ef2e7f"
BUCKET_PASS="I9DaW5V8jKnVN4r7"

ftp_upload() {
  local src="$1" dst="$2"
  curl -s --ftp-create-dirs \
    -T "$src" \
    "ftp://${BUCKET_HOST}/${dst}" \
    -u "${BUCKET_USER}:${BUCKET_PASS}"
}

# ─── Resolve accounts ─────────────────────────────────────────────────────────
# Priority: positional args > env vars > interactive prompt

AGENT_EMAIL="${1:-${AGENT_EMAIL:-}}"
AGENT_GITHUB="${2:-${AGENT_GITHUB:-}}"

echo -e "\n${BOLD}── Agent credentials setup ──${RESET}"

if [[ -z "$AGENT_EMAIL" ]]; then
  ask "Agent Google account (leave blank to skip):"
  read -r AGENT_EMAIL
fi

if [[ -z "$AGENT_GITHUB" ]]; then
  ask "Agent GitHub username (leave blank to skip):"
  read -r AGENT_GITHUB
fi

# ─── Google Workspace / gws ──────────────────────────────────────────────────

if [[ -n "$AGENT_EMAIL" ]]; then
  echo -e "\n${BOLD}── Google Workspace auth for $AGENT_EMAIL ──${RESET}"

  AGENT_SLUG="${AGENT_EMAIL//@/_}"
  BUCKET_GWS_PATH="claude-config/agents/${AGENT_SLUG}/gws-credentials.json"
  GWS_CREDS_REMOTE="${PAPERCLIP_HOME:-/home/bas/app_a3e8da7d-5f3f-46eb-8fd4-f3970cf84173/app/paperclip}/claude-config/agents/${AGENT_SLUG}/gws-credentials.json"

  CLIENT_EXISTS=$(gws auth status 2>/dev/null | grep -o '"client_config_exists": true' || true)
  if [[ -z "$CLIENT_EXISTS" ]]; then
    info "No OAuth client configured — running gws auth setup..."
    gws auth setup
  fi

  info "Logging in as $AGENT_EMAIL (browser will open)..."
  gws auth login

  TMPFILE=$(mktemp)
  gws auth export --unmasked > "$TMPFILE"
  success "Credentials exported"

  info "Uploading credentials to bucket at ${BUCKET_GWS_PATH}..."
  ftp_upload "$TMPFILE" "$BUCKET_GWS_PATH"
  rm -f "$TMPFILE"
  success "Credentials uploaded"

  clever env set GWS_CREDENTIALS_FILE "$GWS_CREDS_REMOTE"
  clever env set GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE "$GWS_CREDS_REMOTE"
  success "GWS_CREDENTIALS_FILE=$GWS_CREDS_REMOTE"

  # ─── Google Cloud / gcloud ────────────────────────────────────────────────

  echo -e "\n${BOLD}── Google Cloud auth for $AGENT_EMAIL ──${RESET}"

  BUCKET_GCLOUD_PATH="claude-config/agents/${AGENT_SLUG}/gcloud"
  CLOUDSDK_CONFIG_REMOTE="${PAPERCLIP_HOME:-/app/paperclip}/claude-config/agents/${AGENT_SLUG}/gcloud"

  ACTIVE=$(gcloud auth list \
    --filter="account=${AGENT_EMAIL} AND status=ACTIVE" \
    --format="value(account)" 2>/dev/null || true)

  if [[ -z "$ACTIVE" ]]; then
    info "Logging in as $AGENT_EMAIL (browser will open)…"
    gcloud auth login "$AGENT_EMAIL" 2>/dev/null || \
      gcloud auth login "$AGENT_EMAIL" --no-launch-browser
  else
    success "$AGENT_EMAIL already authenticated locally"
  fi

  gcloud config set account "$AGENT_EMAIL" --quiet 2>/dev/null || true

  GCLOUD_DIR="${CLOUDSDK_CONFIG:-$HOME/.config/gcloud}"
  info "Uploading credentials to bucket at ${BUCKET_GCLOUD_PATH}…"

  for f in credentials.db access_tokens.db active_config properties; do
    [[ -f "$GCLOUD_DIR/$f" ]] || continue
    ftp_upload "$GCLOUD_DIR/$f" "${BUCKET_GCLOUD_PATH}/${f}"
    success "  $f"
  done

  if [[ -d "$GCLOUD_DIR/configurations" ]]; then
    for f in "$GCLOUD_DIR/configurations/"*; do
      [[ -f "$f" ]] || continue
      ftp_upload "$f" "${BUCKET_GCLOUD_PATH}/configurations/$(basename "$f")"
      success "  configurations/$(basename "$f")"
    done
  fi

  clever env set CLOUDSDK_CONFIG "$CLOUDSDK_CONFIG_REMOTE"
  success "CLOUDSDK_CONFIG=$CLOUDSDK_CONFIG_REMOTE"
else
  warn "No Google account — skipping."
fi

# ─── GitHub ───────────────────────────────────────────────────────────────────

if [[ -n "$AGENT_GITHUB" ]]; then
  echo -e "\n${BOLD}── GitHub auth for $AGENT_GITHUB ──${RESET}"

  # Option 1: token passed directly via env var (no browser needed)
  if [[ -n "${AGENT_GH_TOKEN:-}" ]]; then
    echo "$AGENT_GH_TOKEN" | gh auth login --hostname github.com --with-token
    CURRENT_USER=$(gh api user --jq .login 2>/dev/null || true)
    success "Authenticated as $CURRENT_USER via AGENT_GH_TOKEN"

  # Option 2: already authenticated as the right user
  elif [[ "$(gh api user --jq .login 2>/dev/null || true)" == "$AGENT_GITHUB" ]]; then
    success "Already authenticated as $AGENT_GITHUB"

  # Option 3: browser/device flow
  else
    info "Logging in as $AGENT_GITHUB…"
    info "Tip: set AGENT_GH_TOKEN=<pat> to skip the browser flow."
    gh auth login --hostname github.com --git-protocol https --web
  fi

  CURRENT_USER=$(gh api user --jq .login 2>/dev/null || true)
  if [[ "$CURRENT_USER" == "$AGENT_GITHUB" ]]; then
    GH_TOKEN=$(gh auth token 2>/dev/null || true)
    if [[ -n "$GH_TOKEN" ]]; then
      clever env set GH_TOKEN "$GH_TOKEN"
      success "GH_TOKEN set on Clever Cloud"
    else
      warn "Could not extract token — set manually: clever env set GH_TOKEN <token>"
    fi
  else
    warn "Login may have failed (current: ${CURRENT_USER:-none})"
  fi
else
  warn "No GitHub account — skipping."
fi

# ─── Wire hooks ───────────────────────────────────────────────────────────────

echo -e "\n${BOLD}── Wiring build/run hooks ──${RESET}"
clever env set CC_PRE_BUILD_HOOK "bash scripts/install-tools.sh" && \
  success "CC_PRE_BUILD_HOOK → scripts/install-tools.sh"
clever env set CC_PRE_RUN_HOOK "bash scripts/startup.sh" && \
  success "CC_PRE_RUN_HOOK → scripts/startup.sh"

# ─── Deploy ───────────────────────────────────────────────────────────────────

echo
ask "Deploy now to apply changes? [Y/n]:"
read -r DEPLOY
DEPLOY="${DEPLOY:-Y}"

if [[ "$DEPLOY" =~ ^[Yy]$ ]]; then
  info "Stopping for clean restart…"
  clever stop 2>/dev/null || true
  sleep 3
  clever restart
  success "Deployment triggered!"
else
  warn "Run 'clever stop && clever restart' when ready."
fi

echo
success "Done."
[[ -n "$AGENT_EMAIL"  ]] && echo -e "  Google Workspace: ${CYAN}$AGENT_EMAIL${RESET}"
[[ -n "$AGENT_GITHUB" ]] && echo -e "  GitHub: ${CYAN}$AGENT_GITHUB${RESET}"
