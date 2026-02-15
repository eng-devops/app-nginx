#!/usr/bin/env bash
# Semantic versioning based on conventional commits.
# Usage: semver.sh <branch_name>
# Output: next version (e.g. 1.2.0-rc on release/*, 1.2.0 on main)
# Commit rules: "Feat!:" or "feat!:" -> major; "Feat:" or "feat:" -> minor; "Fix:" or "fix:" -> patch

set -e
BRANCH="${1:-}"

# Find latest tag that looks like semver (v1.2.3 or v1.2.3-rc)
LATEST_TAG=$(git tag -l 'v*' 2>/dev/null | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+(-rc[0-9]*)?$' | sort -V | tail -1 || true)
if [[ -z "$LATEST_TAG" ]]; then
  # No existing tag: start at 0.1.0 for first release
  MAJOR=0
  MINOR=1
  PATCH=0
else
  # Strip 'v' and -rc* for base version
  BASE="${LATEST_TAG#v}"
  BASE="${BASE%-rc*}"
  IFS='.' read -r MAJOR MINOR PATCH <<< "$BASE"
  MAJOR=${MAJOR:-0}
  MINOR=${MINOR:-0}
  PATCH=${PATCH:-0}
fi

# Commits since latest tag (or current commit if no tag)
RANGE="${LATEST_TAG}..HEAD"
if [[ -z "$LATEST_TAG" ]]; then
  COMMITS=$(git log --oneline -1 2>/dev/null || true)
else
  COMMITS=$(git log --oneline "$RANGE" 2>/dev/null || true)
fi

# Determine bump: major (Feat!:), minor (Feat:), patch (Fix:). Order matters.
BUMP="patch"
if [[ -n "$COMMITS" ]]; then
  if echo "$COMMITS" | grep -qiE 'Feat!:|feat!:|BREAKING'; then
    BUMP="major"
  elif echo "$COMMITS" | grep -qiE 'Feat:|feat:'; then
    BUMP="minor"
  elif echo "$COMMITS" | grep -qiE 'Fix:|fix:'; then
    BUMP="patch"
  fi
fi

# Full commit messages for conventional commit detection (Feat!: major, Feat: minor, Fix: patch)
FULL_LOG=""
if [[ -z "$LATEST_TAG" ]]; then
  FULL_LOG=$(git log -1 --format="%s %b" 2>/dev/null || true)
else
  FULL_LOG=$(git log "$RANGE" --format="%s %b" 2>/dev/null || true)
fi
if [[ -n "$FULL_LOG" ]]; then
  if echo "$FULL_LOG" | grep -qiE 'Feat!:|feat!:|BREAKING CHANGE'; then
    BUMP="major"
  elif echo "$FULL_LOG" | grep -qiE 'Feat:|feat:'; then
    [[ "$BUMP" != "major" ]] && BUMP="minor"
  elif echo "$FULL_LOG" | grep -qiE 'Fix:|fix:'; then
    [[ "$BUMP" != "major" && "$BUMP" != "minor" ]] && BUMP="patch"
  fi
fi

case "$BUMP" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
esac

VERSION="${MAJOR}.${MINOR}.${PATCH}"
if [[ "$BRANCH" =~ ^release ]]; then
  VERSION="${VERSION}-rc"
elif [[ "$BRANCH" != "main" ]]; then
  # Not main and not release: shouldn't be called, but output base
  VERSION="${VERSION}"
fi

echo "$VERSION"
