#!/usr/bin/env bash
# tag-release.sh — Create a semver release tag from conventional commits
# Usage: ./scripts/tag-release.sh [major|minor|patch] [--dry-run]
# Requires: git, gh CLI (authenticated)

set -euo pipefail

BUMP="${1:-patch}"
DRY_RUN=false
if [[ "${2:-}" == "--dry-run" ]] || [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  BUMP="${1:-patch}"
  [ "$BUMP" = "--dry-run" ] && BUMP="patch"
fi

die() { echo "[tag-release] ERROR: $*" >&2; exit 1; }
log() { echo "[tag-release] $*"; }

command -v git &>/dev/null || die "git not found."
command -v gh &>/dev/null || die "GitHub CLI (gh) not found."

# Validate bump type
[[ "$BUMP" =~ ^(major|minor|patch)$ ]] || die "Invalid bump type: $BUMP. Use: major, minor, patch"

# Get current version from latest tag or package.json
if git describe --tags --abbrev=0 &>/dev/null; then
  LATEST_TAG=$(git describe --tags --abbrev=0)
  CURRENT_VERSION="${LATEST_TAG#v}"
  log "Latest tag: $LATEST_TAG"
else
  CURRENT_VERSION=$(node -p "require('./package.json').version" 2>/dev/null || echo "0.0.0")
  log "No git tags found. Using package.json version: $CURRENT_VERSION"
fi

# Parse semver
IFS='.' read -r MAJOR MINOR PATCH <<< "${CURRENT_VERSION%%-*}"
MAJOR="${MAJOR:-0}"
MINOR="${MINOR:-0}"
PATCH="${PATCH:-0}"

# Bump version
case "$BUMP" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
NEW_TAG="v${NEW_VERSION}"

log "Bumping: $CURRENT_VERSION -> $NEW_VERSION ($BUMP)"

if [ "$DRY_RUN" = "true" ]; then
  log "[DRY-RUN] Would create tag: $NEW_TAG"
  log "[DRY-RUN] Would push tag and create GitHub Release"
  exit 0
fi

# Ensure working tree is clean
if ! git diff --quiet || ! git diff --cached --quiet; then
  die "Working tree is not clean. Commit or stash changes before tagging."
fi

# Create and push tag
git tag "$NEW_TAG"
git push origin "$NEW_TAG"
log "Tag pushed: $NEW_TAG"

# Create GitHub Release with auto-generated notes
gh release create "$NEW_TAG" \
  --title "$NEW_TAG" \
  --generate-notes \
  --verify-tag
log "GitHub Release created: $NEW_TAG"
