#!/usr/bin/env bash
# CC_PRE_BUILD_HOOK — installs gh, gws, and Hermes CLIs.
# Runs before npm install on each Clever Cloud build.
set -euo pipefail

INSTALL_DIR="/home/bas/.local/bin"
mkdir -p "$INSTALL_DIR"
export PATH="$INSTALL_DIR:$PATH"

# ─── gh (GitHub CLI) ──────────────────────────────────────────────────────────

if [[ -n "${GH_TOKEN:-}" ]]; then
  echo "install-tools: installing gh CLI…"
  GH_VERSION="2.79.0"
  curl -sSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz" \
    | tar -xz --strip-components=2 -C "$INSTALL_DIR" \
        "gh_${GH_VERSION}_linux_amd64/bin/gh"
  echo "install-tools: gh $(gh --version | head -1) installed"
else
  echo "install-tools: GH_TOKEN not set, skipping gh"
fi

# ─── gws (Google Workspace CLI) ──────────────────────────────────────────────

if [[ -n "${GWS_CREDENTIALS_FILE:-}" ]] || [[ -n "${GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE:-}" ]]; then
  echo "install-tools: installing gws CLI…"
  npm install -g @googleworkspace/cli 2>/dev/null
  echo "install-tools: gws $(gws --version 2>/dev/null || echo 'installed') ready"
else
  echo "install-tools: no GWS credentials configured, skipping gws"
fi

# ─── Hermes (Nous Research — Donna's agent runtime) ──────────────────────────

echo "install-tools: installing Hermes agent…"
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
# Hermes installs to ~/.local/bin — make sure it's on PATH for subsequent steps
export PATH="$HOME/.local/bin:$PATH"
echo "install-tools: hermes $(hermes --version 2>/dev/null || echo 'installed') ready"
