#!/usr/bin/env bash
# verify-secrets.sh — Audit which GitHub Secrets are set across all sennacc repos and org
# Usage: ./scripts/verify-secrets.sh [--repo REPO] [--format json|table]

set -euo pipefail

ORG="sennacc"
SINGLE_REPO=""
FORMAT="table"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)   SINGLE_REPO="${2:-}"; shift 2 ;;
    --format) FORMAT="${2:-table}"; shift 2 ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

die() { echo "[verify-secrets] ERROR: $*" >&2; exit 1; }
log() { echo "[verify-secrets] $*"; }

command -v gh &>/dev/null || die "GitHub CLI (gh) not found."
gh auth status &>/dev/null || die "Not authenticated. Run: gh auth login"

# Required secrets per scope
REQUIRED_ORG_SECRETS=(
  CLOUDFLARE_API_KEY
  CLOUDFLARE_EMAIL
  NPM_TOKEN
  SSH_DEPLOY_KEY
  GH_TOKEN
  OP_SERVICE_ACCOUNT_TOKEN
)

REQUIRED_REPO_SECRETS=(
  WORKER_01_IP
  WORKER_02_IP
  WORKER_01_FINGERPRINT
  WORKER_02_FINGERPRINT
  HILL_WEBHOOK_URL
)

log "Auditing org-level secrets for: $ORG"
echo ""

# Check org secrets
echo "=== ORG SECRETS (sennacc) ==="
ORG_SECRETS=$(gh secret list --org "$ORG" --json name -q '.[].name' 2>/dev/null || echo "")
MISSING_ORG=0
for SECRET in "${REQUIRED_ORG_SECRETS[@]}"; do
  if echo "$ORG_SECRETS" | grep -q "^${SECRET}$"; then
    echo "  [OK] $SECRET"
  else
    echo "  [MISSING] $SECRET"
    MISSING_ORG=$((MISSING_ORG + 1))
  fi
done
echo ""

# Check repos
if [ -n "$SINGLE_REPO" ]; then
  REPOS=("$SINGLE_REPO")
else
  # EC2-deployed repos that need repo-level secrets
  REPOS=(executor)
fi

for REPO in "${REPOS[@]}"; do
  echo "=== REPO SECRETS ($ORG/$REPO) ==="
  REPO_SECRETS=$(gh secret list --repo "$ORG/$REPO" --json name -q '.[].name' 2>/dev/null || echo "")
  for SECRET in "${REQUIRED_REPO_SECRETS[@]}"; do
    if echo "$REPO_SECRETS" | grep -q "^${SECRET}$"; then
      echo "  [OK] $SECRET"
    else
      echo "  [MISSING] $SECRET"
    fi
  done
  echo ""
done

if [ "$MISSING_ORG" -gt 0 ]; then
  log "ACTION REQUIRED: $MISSING_ORG org secret(s) missing. Run: ./scripts/setup-org-secrets.sh"
  exit 1
else
  log "All required org secrets are present."
fi
