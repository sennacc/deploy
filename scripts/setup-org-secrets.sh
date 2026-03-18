#!/usr/bin/env bash
# setup-org-secrets.sh — Populate GitHub Org Secrets from 1Password
# Usage: ./scripts/setup-org-secrets.sh [--dry-run]
# Requires: op CLI, gh CLI (authenticated), 1Password vault: blackbox_claude_tokens

set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[DRY-RUN] Simulating secret population (no changes will be made)"
fi

ORG="sennacc"
VAULT="blackbox_claude_tokens"

log() { echo "[setup-org-secrets] $*"; }
die() { echo "[setup-org-secrets] ERROR: $*" >&2; exit 1; }

# Verify required tools
command -v op &>/dev/null || die "1Password CLI (op) not found. Install from https://1password.com/downloads/command-line/"
command -v gh &>/dev/null || die "GitHub CLI (gh) not found. Install from https://cli.github.com/"

# Verify op authenticated
op account list &>/dev/null || die "Not signed in to 1Password. Run: op signin"

# Verify gh authenticated
gh auth status &>/dev/null || die "Not authenticated to GitHub. Run: gh auth login"

log "Populating org secrets for: $ORG"

set_secret() {
  local secret_name="$1"
  local op_ref="$2"
  local scope="${3:-org}"  # 'org' or 'repo:owner/name'

  log "Setting $secret_name..."
  if [ "$DRY_RUN" = "true" ]; then
    log "  [DRY-RUN] Would pipe: op read \"$op_ref\" | gh secret set $secret_name --org $ORG"
    return
  fi

  # SEC-05: pipe directly from op read to gh secret set — no intermediate variable
  if [ "$scope" = "org" ]; then
    op read "$op_ref" | gh secret set "$secret_name" --org "$ORG"
  else
    op read "$op_ref" | gh secret set "$secret_name" --repo "$scope"
  fi
  log "  $secret_name set."
}

# Cloudflare credentials
set_secret "CLOUDFLARE_API_KEY" "op://${VAULT}/Cloudflare-blackbox-claude/api-token"
set_secret "CLOUDFLARE_EMAIL"   "op://${VAULT}/Cloudflare-blackbox-claude/email"

# npm publish token — SEC-05: NPM_TOKEN included
set_secret "NPM_TOKEN" "op://${VAULT}/npm-blackbox-claude/token"

# SSH deploy key for EC2 workers
set_secret "SSH_DEPLOY_KEY" "op://${VAULT}/SSH-deploy-key/private-key"

# GitHub token for branch protection and releases
set_secret "GH_TOKEN" "op://${VAULT}/github-blackbox-claude/api-token"

# 1Password Service Account token for CI usage
set_secret "OP_SERVICE_ACCOUNT_TOKEN" "op://${VAULT}/1password-blackbox-claude/credential"

log "All org secrets populated successfully."
log "Next: run 'gh secret list --org $ORG' to verify."
