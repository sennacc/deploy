#!/usr/bin/env bash
# rotate-secrets.sh — Rotate a GitHub Org Secret from 1Password
# Usage: ./scripts/rotate-secrets.sh <SECRET_NAME>
# Follows the rotation procedure in docs/secrets-rotation.md

set -euo pipefail

SECRET_NAME="${1:-}"
ORG="sennacc"
VAULT="blackbox_claude_tokens"

die() { echo "[rotate-secrets] ERROR: $*" >&2; exit 1; }
log() { echo "[rotate-secrets] $*"; }

[ -z "$SECRET_NAME" ] && die "Usage: $0 <SECRET_NAME>"

# Map secret names to 1Password references
declare -A SECRET_MAP=(
  ["CLOUDFLARE_API_KEY"]="op://${VAULT}/Cloudflare-blackbox-claude/api-token"
  ["CLOUDFLARE_EMAIL"]="op://${VAULT}/Cloudflare-blackbox-claude/email"
  ["NPM_TOKEN"]="op://${VAULT}/npm-blackbox-claude/token"
  ["SSH_DEPLOY_KEY"]="op://${VAULT}/SSH-deploy-key/private-key"
  ["GH_TOKEN"]="op://${VAULT}/github-blackbox-claude/api-token"
  ["OP_SERVICE_ACCOUNT_TOKEN"]="op://${VAULT}/1password-blackbox-claude/credential"
)

OP_REF="${SECRET_MAP[$SECRET_NAME]:-}"
[ -z "$OP_REF" ] && die "Unknown secret: $SECRET_NAME. Known secrets: ${!SECRET_MAP[*]}"

command -v op &>/dev/null || die "1Password CLI (op) not found."
command -v gh &>/dev/null || die "GitHub CLI (gh) not found."
op account list &>/dev/null || die "Not signed in to 1Password. Run: op signin"

log "Rotating $SECRET_NAME for org $ORG"
log "Source: $OP_REF"
log ""
log "Step 1/3: Reading new value from 1Password and updating GitHub..."

# Pipe directly from op to gh — no intermediate variable
op read "$OP_REF" | gh secret set "$SECRET_NAME" --org "$ORG"

log "Step 2/3: Secret updated in GitHub. Verify CI pipelines pass before revoking old credential."
log ""
log "MANUAL STEPS REQUIRED:"
log "  1. Run a CI pipeline to verify the new secret works"
log "  2. Revoke the old credential in the respective service:"
case "$SECRET_NAME" in
  CLOUDFLARE_API_KEY) log "     -> Cloudflare Dashboard > My Profile > API Tokens" ;;
  NPM_TOKEN)          log "     -> npmjs.com > Access Tokens" ;;
  SSH_DEPLOY_KEY)     log "     -> EC2 instances: remove old authorized_key entry" ;;
  GH_TOKEN)           log "     -> GitHub > Settings > Developer settings > Personal access tokens" ;;
  *)                  log "     -> Check the respective service dashboard" ;;
esac
log "  3. Update the rotation date in docs/secrets-rotation.md"
log ""
log "Step 3/3: Done. Remember to update rotation date in docs/secrets-rotation.md"
