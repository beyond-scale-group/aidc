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

# ─── gcloud: credentials are on the FS bucket via CLOUDSDK_CONFIG ─────────────
# CLOUDSDK_CONFIG=/app/paperclip/claude-config/gcloud is set as an env var.
# gcloud reads credentials directly from there — no activation step needed.
# Credentials were uploaded once via scripts/setup-donna-auth.sh.

if [[ -n "${CLOUDSDK_CONFIG:-}" ]] && command -v gcloud &>/dev/null; then
  ACTIVE=$(gcloud auth list --filter="status=ACTIVE" --format="value(account)" 2>/dev/null || true)
  if [[ -n "$ACTIVE" ]]; then
    echo "startup: gcloud active account: $ACTIVE"
    if [[ -n "${GCP_PROJECT_ID:-}" ]]; then
      gcloud config set project "$GCP_PROJECT_ID" --quiet 2>/dev/null || true
    fi
  else
    echo "startup: gcloud config found but no active account — run setup-donna-auth.sh"
  fi
fi
