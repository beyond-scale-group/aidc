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
echo "init-db: BUCKET_MOUNT=$BUCKET_MOUNT"
if [ -n "$BUCKET_MOUNT" ] && [ -d "$BUCKET_MOUNT" ]; then
  PAPERCLIP_DIR="/app/paperclip"
  if [ -L "$PAPERCLIP_DIR" ]; then
    echo "init-db: $PAPERCLIP_DIR is already a symlink -> $(readlink "$PAPERCLIP_DIR")"
  elif [ -d "$PAPERCLIP_DIR" ]; then
    echo "init-db: $PAPERCLIP_DIR is a directory, replacing with symlink"
    cp -a "$PAPERCLIP_DIR"/. "$BUCKET_MOUNT"/ 2>/dev/null || true
    rm -rf "$PAPERCLIP_DIR" 2>&1 || echo "init-db: rm failed, trying with sudo"
    if [ -d "$PAPERCLIP_DIR" ]; then
      # If rm failed, try moving instead
      mv "$PAPERCLIP_DIR" "/app/paperclip.old.$$" 2>&1 || echo "init-db: mv also failed"
    fi
    if [ ! -e "$PAPERCLIP_DIR" ]; then
      ln -sfn "$BUCKET_MOUNT" "$PAPERCLIP_DIR"
      echo "init-db: symlinked $PAPERCLIP_DIR -> $BUCKET_MOUNT"
    else
      echo "init-db: ERROR could not remove $PAPERCLIP_DIR, ls: $(ls -ld "$PAPERCLIP_DIR")"
    fi
  fi
else
  echo "init-db: no bucket mount found"
fi
