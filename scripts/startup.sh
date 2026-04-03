#!/usr/bin/env bash
# CC_PRE_RUN_HOOK — runs before 'npm start' on each Clever Cloud instance boot.
set -euo pipefail

INSTALL_DIR="/home/bas/.local/bin"
export PATH="$INSTALL_DIR:$HOME/.local/bin:$PATH"

# ─── DB: pre-create Drizzle migration journal ─────────────────────────────────
# Clever Cloud PostgreSQL includes PostGIS (spatial_ref_sys table), which tricks
# Paperclip into thinking the DB is non-empty with no migration journal.

psql "$DATABASE_URL" -c "
CREATE TABLE IF NOT EXISTS __drizzle_migrations (
  id SERIAL PRIMARY KEY,
  hash TEXT NOT NULL,
  created_at BIGINT
);
" 2>/dev/null || true

# ─── gws: point to credentials on the FS bucket ──────────────────────────────
# GWS_CREDENTIALS_FILE is set as an env var pointing to the exported credentials
# on the FS bucket. gws reads it directly via GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE.

if [[ -n "${GWS_CREDENTIALS_FILE:-}" ]]; then
  export GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE="$GWS_CREDENTIALS_FILE"
  if command -v gws &>/dev/null; then
    echo "startup: gws credentials configured at $GWS_CREDENTIALS_FILE"
  else
    echo "startup: gws credentials set but CLI not installed — will be installed on next build"
  fi
fi

# ─── gcloud: credentials are on the FS bucket via CLOUDSDK_CONFIG ─────────────
# CLOUDSDK_CONFIG=/app/paperclip/claude-config/gcloud is set as an env var.
# gcloud reads credentials directly from there — no activation step needed.

if [[ -n "${CLOUDSDK_CONFIG:-}" ]] && command -v gcloud &>/dev/null; then
  ACTIVE=$(gcloud auth list --filter="status=ACTIVE" --format="value(account)" 2>/dev/null || true)
  if [[ -n "$ACTIVE" ]]; then
    echo "startup: gcloud active account: $ACTIVE"
    if [[ -n "${GCP_PROJECT_ID:-}" ]]; then
      gcloud config set project "$GCP_PROJECT_ID" --quiet 2>/dev/null || true
    fi
  else
    echo "startup: gcloud config found but no active account — run setup-agent-auth.sh"
  fi
fi

# ─── Donna: Hermes agent (chief of staff) ────────────────────────────────────

DONNA_HOME="${DONNA_HOME:-${PAPERCLIP_HOME:-/app/paperclip}/donna}"
mkdir -p "$DONNA_HOME"

# Resolve app root from script location (startup.sh lives in scripts/ inside the app root)
APP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Seed Donna's identity and config on first run (never overwrite — edits on FS bucket win)
[[ ! -f "$DONNA_HOME/SOUL.md"     ]] && cp "$APP_ROOT/agents/donna/SOUL.md"     "$DONNA_HOME/SOUL.md"     2>/dev/null || true
[[ ! -f "$DONNA_HOME/config.yaml" ]] && cp "$APP_ROOT/agents/donna/config.yaml" "$DONNA_HOME/config.yaml" 2>/dev/null || true

# Always regenerate .env from Clever Cloud env vars — tokens can be rotated
{
  [[ -n "${TELEGRAM_BOT_TOKEN:-}"     ]] && echo "TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN"
  [[ -n "${TELEGRAM_ALLOWED_USERS:-}" ]] && echo "TELEGRAM_ALLOWED_USERS=$TELEGRAM_ALLOWED_USERS"
  [[ -n "${SLACK_BOT_TOKEN:-}"        ]] && echo "SLACK_BOT_TOKEN=$SLACK_BOT_TOKEN"
  [[ -n "${SLACK_APP_TOKEN:-}"        ]] && echo "SLACK_APP_TOKEN=$SLACK_APP_TOKEN"
  [[ -n "${SLACK_ALLOWED_USERS:-}"    ]] && echo "SLACK_ALLOWED_USERS=$SLACK_ALLOWED_USERS"
  [[ -n "${DISCORD_BOT_TOKEN:-}"      ]] && echo "DISCORD_BOT_TOKEN=$DISCORD_BOT_TOKEN"
  [[ -n "${DISCORD_ALLOWED_USERS:-}"  ]] && echo "DISCORD_ALLOWED_USERS=$DISCORD_ALLOWED_USERS"
} > "$DONNA_HOME/.env"
echo "startup: Donna .env written ($(grep -cE '^(TELEGRAM|SLACK|DISCORD)_BOT_TOKEN=' "$DONNA_HOME/.env" 2>/dev/null || echo 0) platform(s) configured)"

if command -v hermes &>/dev/null; then
  HERMES_LOG="${PAPERCLIP_HOME:-/app/paperclip}/donna-hermes.log"
  HERMES_HOME="$DONNA_HOME" hermes gateway run \
    >>"$HERMES_LOG" 2>&1 &
  echo "startup: Donna (Hermes gateway) started — pid=$!, log=$HERMES_LOG"
else
  echo "startup: hermes not found — Donna won't start (rebuild to install)"
fi
