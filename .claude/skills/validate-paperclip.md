# Validate Paperclip Deployment

Run a comprehensive health check on the Paperclip instance deployed on Clever Cloud.

## Steps

### 1. App Status
```bash
clever status --alias aidc-paperclip
```
Verify: app is `running`, note commit hash and instance size.

### 2. Health API
```bash
curl -s https://app-a3e8da7d-5f3f-46eb-8fd4-f3970cf84173.cleverapps.io/api/health
```
Verify: `status: ok`, `authReady: true`, `deploymentMode: authenticated`.

### 3. Recent Deploys
```bash
clever activity --alias aidc-paperclip | head -5
```
Verify: latest deploy is `OK`, no recent `FAIL`.

### 4. FS Bucket Persistence
```bash
clever ssh --alias aidc-paperclip <<'EOF'
BUCKET="$(mount | grep fsbucket | awk '{print $3}')"
echo "BUCKET_MOUNT=$BUCKET"
echo "PAPERCLIP_HOME=$PAPERCLIP_HOME"
echo "MATCH=$([ "$PAPERCLIP_HOME" = "$BUCKET" ] && echo YES || echo NO)"
echo "FILE_COUNT=$(find "$BUCKET" -not -path '*/node_modules/*' -type f 2>/dev/null | wc -l)"
EOF
```
Verify: `MATCH=YES` (PAPERCLIP_HOME points to the bucket mount). File count should be > 0.

### 5. Agent Instructions
```bash
clever ssh --alias aidc-paperclip <<'EOF'
find "$PAPERCLIP_HOME"/instances/default/companies/*/agents/*/instructions -name AGENTS.md 2>/dev/null
EOF
```
Verify: each agent has an `AGENTS.md` file.

### 6. Agent Permissions (settings.json)
```bash
clever ssh --alias aidc-paperclip <<'EOF'
find "$PAPERCLIP_HOME"/instances/default/workspaces/*/.claude -name settings.json 2>/dev/null
EOF
```
Verify: each agent workspace has a `.claude/settings.json` with bash/curl permissions.

### 7. Database
```bash
clever ssh --alias aidc-paperclip <<'EOF'
PGPASSWORD="$POSTGRESQL_ADDON_PASSWORD" psql -h "$POSTGRESQL_ADDON_HOST" -p "$POSTGRESQL_ADDON_PORT" -U "$POSTGRESQL_ADDON_USER" -d "$POSTGRESQL_ADDON_DB" -c "
SELECT 'users' as t, count(*) FROM \"user\"
UNION ALL SELECT 'companies', count(*) FROM companies
UNION ALL SELECT 'agents', count(*) FROM agents
UNION ALL SELECT 'issues', count(*) FROM issues
UNION ALL SELECT 'sessions', count(*) FROM session;
"
EOF
```
Verify: counts are non-zero for users, companies, agents.

### 8. Environment Variables
```bash
clever env --alias aidc-paperclip | grep -E "PAPERCLIP_HOME|PAPERCLIP_DEPLOYMENT|PAPERCLIP_PUBLIC_URL|CC_PRE_RUN_HOOK|CC_PRE_BUILD_HOOK|CLAUDE_CONFIG_DIR|GH_TOKEN|CLAUDE_CODE_OAUTH_TOKEN|BETTER_AUTH_SECRET|DATABASE_URL|SERVE_UI" | sed 's/=.*/=***/'
```
Verify: all required env vars are set.

### 9. DB Backups
```bash
clever ssh --alias aidc-paperclip <<'EOF'
ls -lt "$PAPERCLIP_HOME"/instances/default/data/backups/*.sql 2>/dev/null | head -3
EOF
```
Verify: at least one recent backup exists.

### 10. Run Logs
```bash
clever ssh --alias aidc-paperclip <<'EOF'
find "$PAPERCLIP_HOME"/instances/default/data/run-logs -name '*.ndjson' 2>/dev/null | wc -l
EOF
```
Verify: run logs are being written and accumulating.

## Output

Present results as a table:

| Check | Status | Details |
|-------|--------|---------|
| App Status | PASS/FAIL | ... |
| Health API | PASS/FAIL | ... |
| ... | ... | ... |

Flag any FAIL with recommended fix.
