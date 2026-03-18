#!/usr/bin/env bash
# health-check.sh — Standalone health check for any endpoint
# Usage: ./scripts/health-check.sh <URL> [max-retries] [delay-seconds]
# Validates HTTP status AND body.status == "ok" when present (SEC-10)

set -euo pipefail

URL="${1:-}"
MAX_RETRIES="${2:-10}"
DELAY="${3:-6}"

die() { echo "[health-check] ERROR: $*" >&2; exit 1; }
log() { echo "[health-check] $*"; }

[ -z "$URL" ] && die "Usage: $0 <URL> [max-retries] [delay-seconds]"
command -v curl &>/dev/null || die "curl not found."
command -v jq &>/dev/null || log "WARN: jq not found — body validation will be skipped."

log "Checking: $URL"
log "Max retries: $MAX_RETRIES, delay: ${DELAY}s"

ATTEMPT=0
while [ "$ATTEMPT" -lt "$MAX_RETRIES" ]; do
  ATTEMPT=$((ATTEMPT + 1))
  START=$(date +%s%3N 2>/dev/null || date +%s)

  HTTP_CODE=$(curl -s -o /tmp/health-response \
    -w "%{http_code}" \
    --max-time 10 \
    --connect-timeout 5 \
    "$URL" 2>/dev/null || echo "000")

  END=$(date +%s%3N 2>/dev/null || date +%s)
  ELAPSED=$((END - START))

  log "Attempt $ATTEMPT/$MAX_RETRIES — HTTP $HTTP_CODE (${ELAPSED}ms)"

  if [ "$HTTP_CODE" = "200" ]; then
    BODY=$(cat /tmp/health-response 2>/dev/null || echo "")

    # SEC-10: validate body.status == "ok" when present
    if command -v jq &>/dev/null; then
      BODY_STATUS=$(echo "$BODY" | jq -r '.status' 2>/dev/null || echo "")
      if [ -n "$BODY_STATUS" ]; then
        if [ "$BODY_STATUS" = "ok" ]; then
          log "PASSED: HTTP 200, body.status=ok (${ELAPSED}ms)"
          rm -f /tmp/health-response
          exit 0
        else
          log "FAIL: HTTP 200 but body.status='$BODY_STATUS' (expected 'ok')"
          if [ "$ATTEMPT" -lt "$MAX_RETRIES" ]; then
            sleep "$DELAY"
            continue
          fi
          break
        fi
      fi
    fi

    log "PASSED: HTTP 200 (${ELAPSED}ms)"
    rm -f /tmp/health-response
    exit 0
  fi

  if [ "$ATTEMPT" -lt "$MAX_RETRIES" ]; then
    log "Waiting ${DELAY}s before retry..."
    sleep "$DELAY"
  fi
done

log "FAILED after $MAX_RETRIES attempts. Last HTTP: $HTTP_CODE"
log "Last response body:"
head -20 /tmp/health-response 2>/dev/null || true
rm -f /tmp/health-response
exit 1
