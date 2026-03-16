# Rollback Playbook

Step-by-step rollback procedures for each deploy target. When in doubt, rollback first, investigate second.

---

## CF Worker Rollback (senna-api, senna-gateway)

**Time to rollback: < 2 minutes**

### Automatic (CI-triggered)
When health check fails post-deploy, the `template-api.yml` workflow automatically rolls back via `wrangler rollback`.

### Manual — wrangler CLI
```bash
# Rollback to previous version
CLOUDFLARE_API_KEY="$(op read op://blackbox_claude_tokens/Cloudflare-blackbox-claude/api-token)" \
CLOUDFLARE_EMAIL="$(op read op://blackbox_claude_tokens/Cloudflare-blackbox-claude/email)" \
npx wrangler rollback --env production

# Rollback to specific version ID
npx wrangler rollback <VERSION_ID> --env production

# List versions to find rollback target
npx wrangler versions list
```

### Manual — composite action via workflow_dispatch
1. Go to GitHub Actions in the target repo
2. Run `Rollback CF Worker` workflow (if configured)
3. Input the version ID to rollback to (leave empty for previous)

### Verify
```bash
./scripts/health-check.sh https://api-senna.blackbox.dog/health
```

---

## CF Pages Rollback (senna-ui)

**Time to rollback: < 3 minutes**

### Automatic (CI-triggered)
When health check fails post-deploy, `template-ui.yml` triggers `rollback-pages` action which retries the previous deployment via Cloudflare API.

### Manual — Cloudflare API
```bash
CLOUDFLARE_API_KEY="$(op read op://blackbox_claude_tokens/Cloudflare-blackbox-claude/api-token)"
CLOUDFLARE_EMAIL="$(op read op://blackbox_claude_tokens/Cloudflare-blackbox-claude/email)"

# Get previous deployment ID
curl -s \
  -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
  -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
  "https://api.cloudflare.com/client/v4/accounts/d6071201b3a0ef4f285db819401c4eaf/pages/projects/senna-command-center/deployments?per_page=5" \
  | jq '.result[] | {id, url, created_on}'

# Retry (rollback to) a specific deployment
DEPLOYMENT_ID="<ID from above>"
curl -X POST \
  -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
  -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
  "https://api.cloudflare.com/client/v4/accounts/d6071201b3a0ef4f285db819401c4eaf/pages/projects/senna-command-center/deployments/$DEPLOYMENT_ID/retry"
```

### Manual — via script
```bash
export CLOUDFLARE_API_KEY="..."
export CLOUDFLARE_EMAIL="..."
./actions/rollback-pages/action.yml  # Use via composite action or adapt inline
```

### Verify
```bash
./scripts/health-check.sh https://senna.blackbox.dog
```

---

## EC2 Worker Rollback (senna-executor)

**Time to rollback: 3–5 minutes**

### Automatic (CI-triggered)
`template-worker.yml` captures pre-deploy commit via `$GITHUB_OUTPUT` and runs `rollback-ec2.sh` on failure.

### Manual
```bash
# Load SSH key into agent (NEVER write PEM to disk)
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/claude-workers-key.pem
trap 'ssh-agent -k' EXIT

# Get rollback target commit
ssh ec2-user@<WORKER_IP> "cd /home/ec2-user/senna-worker && git log --oneline -5"

# Rollback
./scripts/rollback-ec2.sh <WORKER_IP> <COMMIT_SHA>

# Or manually over SSH
ssh ec2-user@<WORKER_IP> "
  cd /home/ec2-user/senna-worker
  git reset --hard <COMMIT_SHA>
  npm ci --prefer-offline
  pm2 reload senna-worker --update-env
"
```

### Verify
```bash
./scripts/health-check.sh http://<WORKER_IP>:3000/health
```

---

## npm Package Rollback

**Time to rollback: 5–10 minutes (dist-tag change is instant)**

### Option A — Dist-tag (fastest, no unpublish)
```bash
# Point 'latest' tag to previous version
npm dist-tag add @sennacc/<package>@<PREV_VERSION> latest
```

### Option B — Deprecate broken version
```bash
npm deprecate @sennacc/<package>@<BROKEN_VERSION> "Broken — use <PREV_VERSION>"
```

> Note: npm does not allow unpublish after 72h for public packages.

---

## Emergency Contacts

| Issue | Owner | Action |
|---|---|---|
| CF Worker down | MOSS | `wrangler rollback` |
| CF Pages broken | MOSS | Cloudflare API retry |
| EC2 worker down | LAUDA | `rollback-ec2.sh` + PM2 restart |
| npm bad publish | MOSS | `npm dist-tag` |
| CI pipeline stuck | MOSS | Cancel run + investigate |
| Secret exposed | PIQUET → FANGIO | Rotate immediately via `rotate-secrets.sh` |
