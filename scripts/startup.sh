#!/usr/bin/env bash
# CC_PRE_RUN_HOOK — runs before 'npm start' on each Clever Cloud instance boot.
set -euo pipefail

INSTALL_DIR="/home/bas/.local/bin"
export PATH="$INSTALL_DIR:$PATH"

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
