#!/usr/bin/env bash
# Pre-create Drizzle migration journal on first deploy.
# Clever Cloud's PostgreSQL includes PostGIS (spatial_ref_sys table),
# which tricks Paperclip into thinking the DB is non-empty with no journal.
set -euo pipefail
psql "$DATABASE_URL" -c "
CREATE TABLE IF NOT EXISTS __drizzle_migrations (
  id SERIAL PRIMARY KEY,
  hash TEXT NOT NULL,
  created_at BIGINT
);
" 2>/dev/null || true
