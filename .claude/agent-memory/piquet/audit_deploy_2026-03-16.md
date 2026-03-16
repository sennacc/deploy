---
name: deploy-audit-2026-03-16
description: Security audit findings for @sennacc/deploy — hardcoded IDs, floating @main pins, ssh-keyscan fallback, secret exposure in GITHUB_ENV
type: project
---

Audit conducted 2026-03-16. Full scan of actions/, workflows/, scripts/, docs/.

## Findings Summary

### P1 — High Priority
1. **Hardcoded Cloudflare Account ID** in `actions/deploy-pages/action.yml:117` and `actions/rollback-pages/action.yml:17` (default). Should be an input. Account ID is not a secret but its presence in code means any fork of the action targets the real account.
2. **Hardcoded Zone ID** in `scripts/dns-update.sh:15` (ZONE_ID="5f0fdc889209b826dc86127be6c24645"). Should be an env var or parameter.
3. **All internal composite actions referenced at @main** (floating tag) in all 4 workflow templates. No SHA pin for sennacc/deploy itself. A compromised main branch immediately affects all consumers.
4. **ssh-keyscan fallback** in `actions/deploy-ec2/action.yml:58` and `template-worker.yml:82` — when no fingerprint is provided, falls back to unauthenticated keyscan (TOFU/MITM risk). The fallback should be removed; fingerprint should be required.

### P2 — Medium Priority
5. **Secret value flows through GITHUB_ENV via echo** in `actions/auth-cloudflare/action.yml:19-20`. GitHub masks secrets in logs, but writing to GITHUB_ENV via `echo` (not `>>`) exposes the value if step debug logging is enabled. The deploy-pages and deploy-worker actions inject via env: block which is safer — auth-cloudflare should do the same.
6. **auth-op installs op CLI from agilebits CDN at runtime** (`actions/auth-op/action.yml:23`) with a pinned version string but no checksum verification. A CDN compromise or MITM could serve a malicious binary. Should verify SHA-256 of the downloaded zip.
7. **Secret value captured in subshell** in `actions/auth-op/action.yml:49`: `printf '%s=%s\n' "$ENV_VAR" "$(op read "$OP_REF")"` — the `$(op read ...)` expansion stores the value in the shell's command substitution buffer before writing to GITHUB_ENV. Lower risk than a variable but not zero.

### PASS — Items verified clean
- Zero hardcoded API keys, tokens, or passwords in any tracked file
- SSH key never written to disk — always via ssh-agent in memory (SEC-01 compliant)
- All third-party `uses:` pinned to SHA (actions/checkout, setup-node, upload-artifact, download-artifact, github-script)
- All scripts chmod +x
- Rollback actions have --dry-run mode (rollback-pages, rollback-worker, rollback-ec2 via ssh-agent check)
- No eval with untrusted input (eval only used for `ssh-agent -s` output which is safe)
- No IAM policy documents in this repo (AWS handled by sennacc/infra)
- Health checks do not log credential headers
- No wildcards in permissions blocks; minimal permissions per job
- Concurrency groups prevent concurrent deploys
- StrictHostKeyChecking=yes set in SSH config (when fingerprint provided)

**Why:** Floating @main pins are supply-chain risk. Hardcoded IDs reduce portability and create implicit coupling to prod. ssh-keyscan fallback is MITM-exploitable.
**How to apply:** Flag these in any future deploy action review. Require fingerprint input to be non-empty before accepting EC2 deploy requests.
