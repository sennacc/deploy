#!/usr/bin/env bash
# branch-protect.sh — Apply branch protection to all sennacc repos
# Usage: ./scripts/branch-protect.sh [--dry-run] [--repo REPO_NAME]
# Requires: gh CLI (authenticated with admin:org or repo admin permissions)

set -euo pipefail

ORG="sennacc"
DRY_RUN=false
SINGLE_REPO=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --repo) SINGLE_REPO="${2:-}"; shift 2 ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

log() { echo "[branch-protect] $*"; }
die() { echo "[branch-protect] ERROR: $*" >&2; exit 1; }

command -v gh &>/dev/null || die "GitHub CLI (gh) not found."
gh auth status &>/dev/null || die "Not authenticated. Run: gh auth login"

# All 29 sennacc repos
ALL_REPOS=(
  core memory agents skills hooks
  configs proto db infra deploy docker github
  api gateway orchestrator executor
  ui cli
  tests security audit policies
  logging monitoring mcp vectors
  docs examples sdk-ts sdk-python
)

if [ -n "$SINGLE_REPO" ]; then
  REPOS=("$SINGLE_REPO")
else
  REPOS=("${ALL_REPOS[@]}")
fi

PROTECTED=0
FAILED=0

for REPO in "${REPOS[@]}"; do
  FULL_REPO="$ORG/$REPO"
  log "Protecting $FULL_REPO/main..."

  if [ "$DRY_RUN" = "true" ]; then
    log "  [DRY-RUN] Would apply: enforce_admins=true, required_reviews=1, no force push"
    PROTECTED=$((PROTECTED + 1))
    continue
  fi

  if echo '{"required_status_checks":{"strict":true,"contexts":["quality"]},"enforce_admins":true,"required_pull_request_reviews":{"required_approving_review_count":1,"dismiss_stale_reviews":true},"restrictions":null,"allow_force_pushes":false,"allow_deletions":false}' | \
    gh api "repos/$FULL_REPO/branches/main/protection" \
    --method PUT \
    --header "Accept: application/vnd.github+json" \
    --input - \
    --silent 2>/dev/null; then
    log "  Protected: $FULL_REPO"
    PROTECTED=$((PROTECTED + 1))
  else
    log "  WARN: Failed to protect $FULL_REPO (repo may not exist or missing permissions)"
    FAILED=$((FAILED + 1))
  fi
done

log ""
log "Results: $PROTECTED protected, $FAILED failed"
if [ "$FAILED" -gt 0 ]; then
  log "Some repos failed — check permissions or that repos exist."
  exit 1
fi
log "All repos protected with enforce_admins=true. No force push to main possible."
