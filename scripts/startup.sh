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

# ─── Donna: Hermes agent (chief of staff) ────────────────────────────────────

DONNA_HOME="${DONNA_HOME:-${PAPERCLIP_HOME:-/app/paperclip}/donna}"
mkdir -p "$DONNA_HOME"

# Seed Donna's identity and config on first run (never overwrite — edits on FS bucket win)
[[ ! -f "$DONNA_HOME/SOUL.md"     ]] && cp /app/agents/donna/SOUL.md     "$DONNA_HOME/SOUL.md"
[[ ! -f "$DONNA_HOME/config.yaml" ]] && cp /app/agents/donna/config.yaml "$DONNA_HOME/config.yaml"

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
  HERMES_LOG="/app/paperclip/donna-hermes.log"
  HERMES_DATA_DIR="$DONNA_HOME" hermes gateway run \
    >>"$HERMES_LOG" 2>&1 &
  echo "startup: Donna (Hermes gateway) started — pid=$!, log=$HERMES_LOG"
else
  echo "startup: hermes not found — Donna won't start (rebuild to install)"
fi
