# Secrets Rotation Schedule

All secrets are stored in 1Password vault `blackbox_claude_tokens` and populated to GitHub via `scripts/setup-org-secrets.sh`.

Never hardcode secrets. Never store in intermediate variables. Always pipe: `op read | gh secret set`.

---

## Rotation Schedule

| Secret | Rotation Frequency | Owner | Last Rotated |
|---|---|---|---|
| `CLOUDFLARE_API_KEY` | 90 days | MOSS | 2026-03-13 |
| `CLOUDFLARE_EMAIL` | Never (stable) | MOSS | — |
| `NPM_TOKEN` | 90 days | MOSS | 2026-03-13 |
| `SSH_DEPLOY_KEY` | 180 days | LAUDA | 2026-03-13 |
| `GH_TOKEN` | 90 days | MOSS | 2026-03-13 |
| `OP_SERVICE_ACCOUNT_TOKEN` | 180 days | FANGIO | 2026-03-13 |
| `WORKER_01_FINGERPRINT` | On EC2 rebuild | LAUDA | 2026-03-13 |
| `WORKER_02_FINGERPRINT` | On EC2 rebuild | LAUDA | 2026-03-13 |

**Next rotation due:**
- `CLOUDFLARE_API_KEY`: 2026-06-11
- `NPM_TOKEN`: 2026-06-11
- `GH_TOKEN`: 2026-06-11
- `SSH_DEPLOY_KEY`: 2026-09-09
- `OP_SERVICE_ACCOUNT_TOKEN`: 2026-09-09

---

## Rotation Procedure

### Standard rotation (any secret)

```bash
# Step 1: Generate new credential in the service
# Step 2: Update 1Password vault
#   - Vault: blackbox_claude_tokens
#   - Update the relevant field (do NOT create a new item)

# Step 3: Rotate in GitHub
./scripts/rotate-secrets.sh <SECRET_NAME>
# e.g.: ./scripts/rotate-secrets.sh CLOUDFLARE_API_KEY

# Step 4: Verify CI passes with new credential
# Run a test workflow or push a trivial change

# Step 5: Revoke old credential in service (see service-specific instructions below)

# Step 6: Update "Last Rotated" date in this file
```

### Service-specific revocation

**Cloudflare API Key**
1. Cloudflare Dashboard > My Profile > API Tokens
2. Delete the old Global API Key entry
3. The new key (already in 1Password) is now the only valid key

**NPM Token**
1. npmjs.com > Avatar > Access Tokens
2. Find and delete the old token (by date created)
3. Verify `@sennacc` publish still works: `npm publish --dry-run`

**SSH Deploy Key**
1. On each EC2 instance: `ssh ec2-user@<IP> "sed -i '/OLD_KEY_FINGERPRINT/d' ~/.ssh/authorized_keys"`
2. Coordinate with LAUDA for EC2 access

**GitHub Token (GH_TOKEN)**
1. GitHub > Settings > Developer settings > Personal access tokens
2. Delete the old token (confirm via token fingerprint in 1Password)

---

## Emergency Rotation (Secret Exposed)

If a secret is exposed (committed to code, leaked in logs, etc.):

1. **Immediately revoke** the secret in the service dashboard (do not wait)
2. Generate a new credential
3. Update 1Password: `op edit item <ITEM> --vault blackbox_claude_tokens <field>=<new-value>`
4. Run: `./scripts/rotate-secrets.sh <SECRET_NAME>`
5. Notify FANGIO (CISO) for audit trail
6. Check git history for exposure scope: `git log --all -S "SECRET_VALUE" --source`
7. If committed: contact GitHub Support to purge from history

---

## Audit Verification

```bash
# Verify all required secrets are present
./scripts/verify-secrets.sh

# List all org secrets (names only — values are never shown)
gh secret list --org sennacc
```
