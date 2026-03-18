#!/usr/bin/env bash
# changelog.sh — Generate a CHANGELOG.md entry from conventional commits
# Usage: ./scripts/changelog.sh <new-version> [from-tag]
# Follows conventional commits: feat:, fix:, chore:, docs:, refactor:

set -euo pipefail

NEW_VERSION="${1:-}"
FROM_TAG="${2:-}"

die() { echo "[changelog] ERROR: $*" >&2; exit 1; }
log() { echo "[changelog] $*" >&2; }

[ -z "$NEW_VERSION" ] && die "Usage: $0 <new-version> [from-tag]"

command -v git &>/dev/null || die "git not found."

# Determine range
if [ -z "$FROM_TAG" ]; then
  if git describe --tags --abbrev=0 &>/dev/null; then
    FROM_TAG=$(git describe --tags --abbrev=0)
  else
    FROM_TAG=$(git rev-list --max-parents=0 HEAD)
    log "No previous tag found. Using initial commit: $FROM_TAG"
  fi
fi

DATE=$(date +%Y-%m-%d)
TAG="v${NEW_VERSION#v}"

log "Generating changelog from $FROM_TAG to HEAD for $TAG"

# Collect commits by type
FEATURES=$(git log "${FROM_TAG}..HEAD" --oneline --no-merges \
  | grep -E '^[a-f0-9]+ feat(\([^)]+\))?:' | sed 's/^[a-f0-9]* //' || true)
FIXES=$(git log "${FROM_TAG}..HEAD" --oneline --no-merges \
  | grep -E '^[a-f0-9]+ fix(\([^)]+\))?:' | sed 's/^[a-f0-9]* //' || true)
CHORES=$(git log "${FROM_TAG}..HEAD" --oneline --no-merges \
  | grep -E '^[a-f0-9]+ (chore|ci|refactor|docs)(\([^)]+\))?:' | sed 's/^[a-f0-9]* //' || true)
BREAKING=$(git log "${FROM_TAG}..HEAD" --oneline --no-merges \
  | grep -E 'BREAKING CHANGE|!:' | sed 's/^[a-f0-9]* //' || true)

# Build entry
ENTRY="## [$TAG] - $DATE"$'\n'

if [ -n "$BREAKING" ]; then
  ENTRY+=$'\n'"### BREAKING CHANGES"$'\n'
  while IFS= read -r line; do
    [ -n "$line" ] && ENTRY+="- $line"$'\n'
  done <<< "$BREAKING"
fi

if [ -n "$FEATURES" ]; then
  ENTRY+=$'\n'"### Features"$'\n'
  while IFS= read -r line; do
    [ -n "$line" ] && ENTRY+="- $line"$'\n'
  done <<< "$FEATURES"
fi

if [ -n "$FIXES" ]; then
  ENTRY+=$'\n'"### Bug Fixes"$'\n'
  while IFS= read -r line; do
    [ -n "$line" ] && ENTRY+="- $line"$'\n'
  done <<< "$FIXES"
fi

if [ -n "$CHORES" ]; then
  ENTRY+=$'\n'"### Chores"$'\n'
  while IFS= read -r line; do
    [ -n "$line" ] && ENTRY+="- $line"$'\n'
  done <<< "$CHORES"
fi

# Prepend to CHANGELOG.md
CHANGELOG="CHANGELOG.md"
if [ -f "$CHANGELOG" ]; then
  EXISTING=$(cat "$CHANGELOG")
  # Skip existing header line if present
  if echo "$EXISTING" | head -1 | grep -q "^# Changelog"; then
    HEADER=$(echo "$EXISTING" | head -1)
    BODY=$(echo "$EXISTING" | tail -n +2)
    printf '%s\n\n%s\n\n%s\n' "$HEADER" "$ENTRY" "$BODY" > "$CHANGELOG"
  else
    printf '%s\n\n%s\n' "$ENTRY" "$EXISTING" > "$CHANGELOG"
  fi
else
  printf '# Changelog\n\n%s\n' "$ENTRY" > "$CHANGELOG"
fi

log "CHANGELOG.md updated with entry for $TAG"
head -30 "$CHANGELOG"
