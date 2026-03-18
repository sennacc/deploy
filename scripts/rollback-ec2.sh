#!/usr/bin/env bash
# rollback-ec2.sh — Roll back an EC2 worker to a specific git commit
# Usage: ./scripts/rollback-ec2.sh <ec2-host> <commit-sha> [app-name] [app-dir]
# SSH key must be loaded in ssh-agent before calling this script (SEC-01)

set -euo pipefail

EC2_HOST="${1:-}"
COMMIT_SHA="${2:-}"
APP_NAME="${3:-senna-worker}"
APP_DIR="${4:-/home/ec2-user/senna-worker}"
EC2_USER="${EC2_USER:-ec2-user}"

die() { echo "[rollback-ec2] ERROR: $*" >&2; exit 1; }
log() { echo "[rollback-ec2] $*"; }

[ -z "$EC2_HOST" ]   && die "Usage: $0 <ec2-host> <commit-sha> [app-name] [app-dir]"
[ -z "$COMMIT_SHA" ] && die "Usage: $0 <ec2-host> <commit-sha> [app-name] [app-dir]"

# Verify SSH agent has key loaded (SEC-01: key must never be passed on CLI)
if ! ssh-add -l &>/dev/null; then
  die "No SSH key in ssh-agent. Load with: ssh-add ~/.ssh/your-key.pem"
fi

log "Rolling back $APP_NAME on $EC2_HOST to commit $COMMIT_SHA"
log "App directory: $APP_DIR"

# Verify commit SHA format (basic sanity check)
if ! echo "$COMMIT_SHA" | grep -qE '^[a-f0-9]{7,40}$'; then
  die "Invalid commit SHA format: $COMMIT_SHA"
fi

log "Connecting to $EC2_HOST..."
ssh \
  -o StrictHostKeyChecking=yes \
  -o ConnectTimeout=15 \
  "${EC2_USER}@${EC2_HOST}" \
  "set -euo pipefail
   echo 'Connected to EC2'
   cd ${APP_DIR}
   CURRENT=\$(git rev-parse HEAD)
   echo \"Current commit: \$CURRENT\"
   echo \"Rolling back to: ${COMMIT_SHA}\"

   git fetch origin
   git reset --hard ${COMMIT_SHA}
   npm ci --prefer-offline

   if node -p \"require('./package.json').scripts?.build || ''\" | grep -q .; then
     echo 'Running build...'
     npm run build
   fi

   pm2 reload ${APP_NAME} --update-env
   ROLLED=\$(git rev-parse HEAD)
   echo \"Rollback complete. Now at: \$ROLLED\""

log "Rollback complete. Verify health check manually:"
log "  ./scripts/health-check.sh http://${EC2_HOST}:3000/health"
