#!/usr/bin/env bash
# CC_PRE_BUILD_HOOK — installs gh, gws, gcloud, and Hermes CLIs.
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
  if npm install -g @googleworkspace/cli 2>/dev/null; then
    echo "install-tools: gws $(gws --version 2>/dev/null || echo 'installed') ready"
  else
    echo "install-tools: WARNING — gws install failed, skipping"
  fi
else
  echo "install-tools: no GWS credentials configured, skipping gws"
fi

# ─── gcloud (Google Cloud CLI) ────────────────────────────────────────────────

if [[ -n "${GCP_SA_KEY:-}" ]]; then
  echo "install-tools: installing gcloud CLI…"
  GCLOUD_DIR="/home/bas/google-cloud-sdk"
  if [[ ! -d "$GCLOUD_DIR" ]]; then
    if curl -sSL "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz" \
        | tar -xz -C /home/bas; then
      ln -sf "$GCLOUD_DIR/bin/gcloud" "$INSTALL_DIR/gcloud"
      ln -sf "$GCLOUD_DIR/bin/gsutil" "$INSTALL_DIR/gsutil"
      ln -sf "$GCLOUD_DIR/bin/bq"     "$INSTALL_DIR/bq"
      echo "install-tools: gcloud $($GCLOUD_DIR/bin/gcloud --version | head -1) installed"
    else
      echo "install-tools: WARNING — gcloud install failed, skipping"
    fi
  else
    ln -sf "$GCLOUD_DIR/bin/gcloud" "$INSTALL_DIR/gcloud" 2>/dev/null || true
    echo "install-tools: gcloud already present"
  fi
else
  echo "install-tools: GCP_SA_KEY not set, skipping gcloud"
fi

# ─── Hermes (Nous Research — Donna's agent runtime) ──────────────────────────

echo "install-tools: installing Hermes agent…"
if curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash; then
  export PATH="$HOME/.local/bin:$PATH"
  echo "install-tools: hermes $(hermes --version 2>/dev/null || echo 'installed') ready"
else
  echo "install-tools: WARNING — Hermes install failed; Donna won't start (check URL or try rebuilding)"
fi
