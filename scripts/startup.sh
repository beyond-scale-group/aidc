#!/usr/bin/env bash
# CC_PRE_RUN_HOOK — runs before 'npm start' on each Clever Cloud instance boot.
# Handles: DB migration journal bootstrap + gcloud service account activation.
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

# ─── gcloud: activate service account from env var ────────────────────────────

if [[ -n "${GCP_SA_KEY:-}" ]]; then
  GCP_KEY_FILE="/tmp/gcp-sa-key.json"
  echo "$GCP_SA_KEY" | base64 -d > "$GCP_KEY_FILE"
  chmod 600 "$GCP_KEY_FILE"

  if command -v gcloud &>/dev/null; then
    gcloud auth activate-service-account --key-file="$GCP_KEY_FILE" --quiet
    if [[ -n "${GCP_PROJECT_ID:-}" ]]; then
      gcloud config set project "$GCP_PROJECT_ID" --quiet
    fi
    echo "startup: gcloud authenticated as $(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null)"
  else
    echo "startup: gcloud binary not found (install-tools may have been skipped)"
  fi

  # Also set for Google SDKs / client libraries
  export GOOGLE_APPLICATION_CREDENTIALS="$GCP_KEY_FILE"
  echo "startup: GOOGLE_APPLICATION_CREDENTIALS=$GCP_KEY_FILE"
else
  echo "startup: GCP_SA_KEY not set, skipping gcloud auth"
fi
