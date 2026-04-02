#!/usr/bin/env bash
# CC_PRE_RUN_HOOK — runs before 'npm start' on each Clever Cloud instance boot.
set -euo pipefail

INSTALL_DIR="/home/bas/.local/bin"
export PATH="$INSTALL_DIR:$PATH"

# ─── FS Bucket: symlink /app/paperclip to the persistent NFS mount ───────────
# CC_FS_BUCKET mounts relative to APP_HOME, so the actual NFS path is
# $APP_HOME/app/paperclip while /app/paperclip is a separate ephemeral directory.
BUCKET_MOUNT="$(mount | grep fsbucket | awk '{print $3}')"
echo "startup: BUCKET_MOUNT=${BUCKET_MOUNT:-<not found>}"
if [ -n "$BUCKET_MOUNT" ] && [ -d "$BUCKET_MOUNT" ]; then
  if [ "/app/paperclip" != "$BUCKET_MOUNT" ]; then
    if [ -d /app/paperclip ] && [ ! -L /app/paperclip ]; then
      cp -a /app/paperclip/. "$BUCKET_MOUNT"/ 2>/dev/null || true
      rm -rf /app/paperclip 2>/dev/null || true
    fi
    ln -sfn "$BUCKET_MOUNT" /app/paperclip 2>/dev/null || true
    echo "startup: symlinked /app/paperclip -> $BUCKET_MOUNT"
  fi
else
  echo "startup: no bucket mount found"
fi

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
