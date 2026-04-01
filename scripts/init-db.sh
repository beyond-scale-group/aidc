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

# 2. Ensure /app/paperclip points to the persistent FS bucket.
#    CC_FS_BUCKET mounts at $APP_HOME/app/paperclip (e.g. /home/bas/<app-id>/app/paperclip)
#    but PAPERCLIP_HOME=/app/paperclip is a separate ephemeral directory.
#    Copy any existing ephemeral data into the bucket, then replace with a symlink.
BUCKET_MOUNT="$(mount | grep fsbucket | awk '{print $3}')"
if [ -n "$BUCKET_MOUNT" ] && [ -d "$BUCKET_MOUNT" ]; then
  PAPERCLIP_DIR="/app/paperclip"
  if [ -d "$PAPERCLIP_DIR" ] && [ ! -L "$PAPERCLIP_DIR" ]; then
    # Move any data already written to ephemeral disk into the bucket
    cp -a "$PAPERCLIP_DIR"/. "$BUCKET_MOUNT"/ 2>/dev/null || true
    rm -rf "$PAPERCLIP_DIR"
    ln -sfn "$BUCKET_MOUNT" "$PAPERCLIP_DIR"
    echo "init-db: symlinked $PAPERCLIP_DIR -> $BUCKET_MOUNT"
  fi
fi
