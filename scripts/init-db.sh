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

# 2. Ensure PAPERCLIP_HOME points to the persistent FS bucket.
#    CC_FS_BUCKET mounts relative to APP_HOME, so the actual NFS path is
#    $APP_HOME/app/paperclip while PAPERCLIP_HOME=/app/paperclip is ephemeral.
#    Export the corrected PAPERCLIP_HOME so Paperclip writes to the bucket.
BUCKET_MOUNT="$(mount | grep fsbucket | awk '{print $3}')"
echo "init-db: BUCKET_MOUNT=${BUCKET_MOUNT:-<not found>}"
if [ -n "$BUCKET_MOUNT" ] && [ -d "$BUCKET_MOUNT" ]; then
  if [ "/app/paperclip" != "$BUCKET_MOUNT" ]; then
    # Copy any data already on the ephemeral disk into the bucket
    if [ -d /app/paperclip ] && [ ! -L /app/paperclip ]; then
      cp -a /app/paperclip/. "$BUCKET_MOUNT"/ 2>/dev/null || true
      rm -rf /app/paperclip 2>/dev/null || true
    fi
    # Create symlink so any hardcoded /app/paperclip references work
    ln -sfn "$BUCKET_MOUNT" /app/paperclip 2>/dev/null || true
    echo "init-db: symlinked /app/paperclip -> $BUCKET_MOUNT"
  fi
else
  echo "init-db: no bucket mount found"
fi
