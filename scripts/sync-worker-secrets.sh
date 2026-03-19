#!/usr/bin/env bash
# sync-worker-secrets.sh — Sync CF Worker secrets from 1Password vault
# Usage: ./scripts/sync-worker-secrets.sh [--dry-run] [--worker senna-api|senna-api-stage|senna-gateway]
# Requires: op CLI, wrangler CLI, 1Password vault: senna_agent_credentials
#
# This script reads secrets from 1Password and sets them on Cloudflare Workers
# via wrangler. It is the SENNA-side equivalent of setup-org-secrets.sh (GitHub).

set -euo pipefail

DRY_RUN=false
WORKER="senna-api"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --worker)  WORKER="${2:-senna-api}"; shift 2 ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

VAULT_CORTEX="blackbox_claude_tokens"
VAULT_AGENTS="senna_agent_credentials"

log() { echo "[sync-worker-secrets] $*"; }
die() { echo "[sync-worker-secrets] ERROR: $*" >&2; exit 1; }

command -v op &>/dev/null || die "1Password CLI (op) not found"
command -v npx &>/dev/null || die "npx not found (install Node.js)"

log "Syncing secrets to Worker: $WORKER"

set_worker_secret() {
  local secret_name="$1"
  local op_ref="$2"

  if [ "$DRY_RUN" = "true" ]; then
    log "  [DRY-RUN] Would set $secret_name on $WORKER from $op_ref"
    return
  fi

  log "  Setting $secret_name..."
  op read "$op_ref" | npx wrangler secret put "$secret_name" --name "$WORKER" 2>/dev/null
  log "  $secret_name set."
}

set_literal_secret() {
  local secret_name="$1"
  local value="$2"

  if [ "$DRY_RUN" = "true" ]; then
    log "  [DRY-RUN] Would set $secret_name on $WORKER (literal)"
    return
  fi

  log "  Setting $secret_name..."
  echo -n "$value" | npx wrangler secret put "$secret_name" --name "$WORKER" 2>/dev/null
  log "  $secret_name set."
}

# --- SENNA Runtime secrets (from 1Password) ---

# Auth & sessions
set_worker_secret "SERVICE_KEY"       "op://${VAULT_AGENTS}/senna-service-key/password"
set_worker_secret "ADMIN_KEY"         "op://${VAULT_AGENTS}/senna-admin-key/password"
set_worker_secret "WORKER_API_KEY"    "op://${VAULT_AGENTS}/senna-worker-api-key/password"
set_worker_secret "SESSION_SECRET"    "op://${VAULT_AGENTS}/senna-session-secret/password"
set_worker_secret "AUTH_KEY_HMAC_SECRET" "op://${VAULT_AGENTS}/senna-hmac-secret/password"

# AI
set_worker_secret "ANTHROPIC_API_KEY" "op://${VAULT_CORTEX}/Anthropic-sennacc_F1 Team/api-key"

# Observability
set_worker_secret "SENTRY_DSN"        "op://${VAULT_AGENTS}/senna-sentry-dsn/password"
set_worker_secret "GRAFANA_API_KEY"   "op://${VAULT_AGENTS}/senna-grafana-api-key/password"
set_worker_secret "GRAFANA_METRICS_URL" "op://${VAULT_AGENTS}/senna-grafana-metrics-url/url"

# Agent work credentials (SENNA agents access to work repos)
set_worker_secret "AGENT_GITHUB_TOKEN" "op://${VAULT_AGENTS}/github-agents-pat/password"

# Infra literals
set_literal_secret "NODE_ENV"           "production"
set_literal_secret "WORKER_ID"          "$WORKER"
set_literal_secret "ALLOWED_WORKER_IPS" "98.82.21.83,32.192.38.144"
set_literal_secret "ALLOWED_ORIGINS"    "https://painel.sennacc.com,https://stage.sennacc.com"
set_literal_secret "WORKER_01_URL"      "http://98.82.21.83:3000"

log "All secrets synced to $WORKER."
log "Next: run 'npx wrangler secret list --name $WORKER' to verify."
