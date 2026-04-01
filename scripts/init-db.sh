#!/usr/bin/env bash
# Pre-run hook for Clever Cloud deployments.
set -euo pipefail

# 1. Pre-create Drizzle migration journal on first deploy.
#    Clever Cloud's PostgreSQL includes PostGIS (spatial_ref_sys table),
#    which tricks Paperclip into thinking the DB is non-empty with no journal.
psql "$DATABASE_URL" -c "
CREATE TABLE IF NOT EXISTS __drizzle_migrations (
  id SERIAL PRIMARY KEY,
  hash TEXT NOT NULL,
  created_at BIGINT
);
" 2>/dev/null || true

# 2. Symlink /app/paperclip to the FS bucket mount so PAPERCLIP_HOME
#    points to persistent storage instead of the ephemeral local disk.
#    CC_FS_BUCKET mounts at $APP_HOME/app/paperclip but PAPERCLIP_HOME=/app/paperclip
#    resolves to a different (ephemeral) path.
BUCKET_MOUNT="${APP_HOME}/app/paperclip"
if [ -d "$BUCKET_MOUNT" ] && [ "$(realpath /app/paperclip 2>/dev/null)" != "$(realpath "$BUCKET_MOUNT" 2>/dev/null)" ]; then
  rm -rf /app/paperclip
  ln -sfn "$BUCKET_MOUNT" /app/paperclip
  echo "init-db: symlinked /app/paperclip -> $BUCKET_MOUNT"
fi
