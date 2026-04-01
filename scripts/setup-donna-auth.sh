#!/usr/bin/env bash
# Setup Donna's Google and GitHub credentials on the FS bucket.
# Run this once locally after creating her accounts.
# Prerequisites: gcloud, gh, clever, curl
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

DONNA_EMAIL="donna.ai@the-shift.ai"
DONNA_GITHUB="donna-bsg"

BUCKET_HOST="bucket-a99c8ef2-e7f2-4230-9ea5-69446996fe92-fsbucket.services.clever-cloud.com"
BUCKET_USER="ua99c8ef2e7f"
BUCKET_PASS="I9DaW5V8jKnVN4r7"
BUCKET_GCLOUD_PATH="claude-config/gcloud"

ftp_upload() {
  local src="$1"
  local dst="$2"
  curl -s --ftp-create-dirs \
    -T "$src" \
    "ftp://${BUCKET_HOST}/${dst}" \
    -u "${BUCKET_USER}:${BUCKET_PASS}"
}

# ─── Google / gcloud ──────────────────────────────────────────────────────────

echo -e "\n${BOLD}── Google auth for $DONNA_EMAIL ──${RESET}"

if ! command -v gcloud &>/dev/null; then
  warn "gcloud not found locally. Install it from https://cloud.google.com/sdk/docs/install"
  warn "Skipping Google setup."
else
  ACTIVE=$(gcloud auth list \
    --filter="account=${DONNA_EMAIL} AND status=ACTIVE" \
    --format="value(account)" 2>/dev/null || true)

  if [[ -z "$ACTIVE" ]]; then
    info "Logging in as $DONNA_EMAIL (browser will open)…"
    gcloud auth login "$DONNA_EMAIL" --no-launch-browser 2>/dev/null || \
    gcloud auth login "$DONNA_EMAIL"
  else
    success "$DONNA_EMAIL already authenticated locally"
  fi

  # Switch active account to donna so the config files reflect her
  gcloud config set account "$DONNA_EMAIL" --quiet 2>/dev/null || true

  GCLOUD_DIR="${CLOUDSDK_CONFIG:-$HOME/.config/gcloud}"

  info "Uploading gcloud credentials to FS bucket…"

  # Core credential store
  for f in credentials.db access_tokens.db active_config properties; do
    [[ -f "$GCLOUD_DIR/$f" ]] || continue
    ftp_upload "$GCLOUD_DIR/$f" "${BUCKET_GCLOUD_PATH}/${f}"
    success "  $f"
  done

  # Named configurations
  if [[ -d "$GCLOUD_DIR/configurations" ]]; then
    for f in "$GCLOUD_DIR/configurations/"*; do
      [[ -f "$f" ]] || continue
      ftp_upload "$f" "${BUCKET_GCLOUD_PATH}/configurations/$(basename "$f")"
      success "  configurations/$(basename "$f")"
    done
  fi

  # Point the app at the bucket gcloud config
  clever env set CLOUDSDK_CONFIG /app/paperclip/claude-config/gcloud
  success "CLOUDSDK_CONFIG=/app/paperclip/claude-config/gcloud set on Clever Cloud"
fi

# ─── GitHub ───────────────────────────────────────────────────────────────────

echo -e "\n${BOLD}── GitHub auth for $DONNA_GITHUB ──${RESET}"

if ! command -v gh &>/dev/null; then
  warn "gh CLI not found. Install from https://cli.github.com"
  warn "Skipping GitHub setup."
else
  CURRENT_USER=$(gh api user --jq .login 2>/dev/null || true)

  if [[ "$CURRENT_USER" != "$DONNA_GITHUB" ]]; then
    info "Logging in as $DONNA_GITHUB (browser will open)…"
    gh auth login --hostname github.com --git-protocol https --web
    CURRENT_USER=$(gh api user --jq .login 2>/dev/null || true)
  fi

  if [[ "$CURRENT_USER" == "$DONNA_GITHUB" ]]; then
    success "Authenticated as $CURRENT_USER"

    # Extract the token gh is using
    GH_TOKEN=$(gh auth token 2>/dev/null || true)

    if [[ -n "$GH_TOKEN" ]]; then
      clever env set GH_TOKEN "$GH_TOKEN"
      success "GH_TOKEN set on Clever Cloud"
    else
      warn "Could not extract token — set GH_TOKEN manually via: clever env set GH_TOKEN <token>"
    fi
  else
    warn "Login may have failed. Current user: ${CURRENT_USER:-none}"
  fi
fi

# ─── Wire hooks if not already set ───────────────────────────────────────────

echo -e "\n${BOLD}── Wiring build/run hooks ──${RESET}"

clever env set CC_PRE_BUILD_HOOK "bash scripts/install-tools.sh" 2>/dev/null && \
  success "CC_PRE_BUILD_HOOK → scripts/install-tools.sh" || true

clever env set CC_PRE_RUN_HOOK "bash scripts/startup.sh" 2>/dev/null && \
  success "CC_PRE_RUN_HOOK → scripts/startup.sh" || true

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
success "Donna's credentials are set up."
echo -e "  Google: ${CYAN}$DONNA_EMAIL${RESET} credentials on FS bucket"
echo -e "  GitHub: ${CYAN}$DONNA_GITHUB${RESET} token on Clever Cloud"
