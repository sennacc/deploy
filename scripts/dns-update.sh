#!/usr/bin/env bash
# dns-update.sh — Update a Cloudflare DNS record via API (not UI)
# Usage: ./scripts/dns-update.sh <record-name> <record-type> <content> [proxy]
# Example: ./scripts/dns-update.sh api-senna.blackbox.dog A 1.2.3.4 true
# Requires: CLOUDFLARE_API_KEY, CLOUDFLARE_EMAIL, CF_ZONE_ID env vars (X-Auth-Key mode)

set -euo pipefail

RECORD_NAME="${1:-}"
RECORD_TYPE="${2:-}"
CONTENT="${3:-}"
PROXIED="${4:-false}"

CF_API="https://api.cloudflare.com/client/v4"
# SEC-09: Zone ID must be provided via env var — never hardcoded
[ -z "${CF_ZONE_ID:-}" ] && die "CF_ZONE_ID not set (export CF_ZONE_ID=<your-zone-id>)"
ZONE_ID="${CF_ZONE_ID}"

die() { echo "[dns-update] ERROR: $*" >&2; exit 1; }
log() { echo "[dns-update] $*"; }

[ -z "$RECORD_NAME" ] && die "Usage: $0 <record-name> <record-type> <content> [proxied=false]"
[ -z "$RECORD_TYPE" ] && die "record-type required (A, CNAME, TXT, MX)"
[ -z "$CONTENT" ]     && die "content required"

# SEC-09: credentials must be in environment — never hardcoded
[ -z "${CLOUDFLARE_API_KEY:-}" ] && die "CLOUDFLARE_API_KEY not set"
[ -z "${CLOUDFLARE_EMAIL:-}" ]   && die "CLOUDFLARE_EMAIL not set"

log "Updating DNS: $RECORD_NAME ($RECORD_TYPE) -> $CONTENT (proxied: $PROXIED)"

# Check if record exists
EXISTING=$(curl -sf \
  -H "X-Auth-Key: ${CLOUDFLARE_API_KEY}" \
  -H "X-Auth-Email: ${CLOUDFLARE_EMAIL}" \
  "${CF_API}/zones/${ZONE_ID}/dns_records?name=${RECORD_NAME}&type=${RECORD_TYPE}" \
  | jq -r '.result[0].id // empty')

PAYLOAD=$(cat <<EOF
{
  "type": "$RECORD_TYPE",
  "name": "$RECORD_NAME",
  "content": "$CONTENT",
  "proxied": $PROXIED,
  "ttl": 1
}
EOF
)

if [ -n "$EXISTING" ]; then
  log "Updating existing record: $EXISTING"
  RESULT=$(curl -sf -X PUT \
    -H "X-Auth-Key: ${CLOUDFLARE_API_KEY}" \
    -H "X-Auth-Email: ${CLOUDFLARE_EMAIL}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    "${CF_API}/zones/${ZONE_ID}/dns_records/${EXISTING}")
else
  log "Creating new record"
  RESULT=$(curl -sf -X POST \
    -H "X-Auth-Key: ${CLOUDFLARE_API_KEY}" \
    -H "X-Auth-Email: ${CLOUDFLARE_EMAIL}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    "${CF_API}/zones/${ZONE_ID}/dns_records")
fi

SUCCESS=$(echo "$RESULT" | jq -r '.success')
if [ "$SUCCESS" = "true" ]; then
  RECORD_ID=$(echo "$RESULT" | jq -r '.result.id')
  log "DNS record updated successfully. ID: $RECORD_ID"
else
  ERRORS=$(echo "$RESULT" | jq -r '.errors[].message' 2>/dev/null || echo "Unknown error")
  die "DNS update failed: $ERRORS"
fi
