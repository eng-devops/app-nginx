#!/usr/bin/env bash
# Versionamento semântico por branch.
# Uso: semver.sh <branch_name>
#
# - release: calcula próximo bump (Feat! -> major, Feat -> minor, Fix -> patch),
#   última tag ou v0.1.0, e sufixo -rc (ou -rc.1, -rc.2... se já existir RC para essa base).
# - develop: usa a última tag que é ancestral de HEAD (a tag “vai” para develop no merge).
# - main: usa a última tag -rc ancestral de HEAD e devolve a versão final (sem -rc).
# - demais branches: não produz versão semântica (build usa env-sha).

set -e
BRANCH="${1:-}"

# ---------- RELEASE: calcular próxima versão com bump + -rc (e contador se já existir)
if [[ "$BRANCH" =~ ^release ]]; then
  # Última tag semver (v1.2.3 ou v1.2.3-rc ou v1.2.3-rc.1)
  LATEST_TAG=$(git tag -l 'v*' 2>/dev/null | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+(-rc(\.[0-9]+)?)?$' | sort -V | tail -1 || true)

  if [[ -z "$LATEST_TAG" ]]; then
    MAJOR=0
    MINOR=1
    PATCH=0
    RANGE=""
  else
    BASE="${LATEST_TAG#v}"
    BASE="${BASE%-rc*}"
    IFS='.' read -r MAJOR MINOR PATCH <<< "$BASE"
    MAJOR=${MAJOR:-0}
    MINOR=${MINOR:-0}
    PATCH=${PATCH:-0}
    RANGE="${LATEST_TAG}..HEAD"
  fi

  # Commits desde a última tag (ou só o último commit se não há tag)
  if [[ -z "$RANGE" ]]; then
    COMMITS=$(git log --oneline -1 2>/dev/null || true)
    FULL_LOG=$(git log -1 --format="%s %b" 2>/dev/null || true)
  else
    COMMITS=$(git log --oneline "$RANGE" 2>/dev/null || true)
    FULL_LOG=$(git log "$RANGE" --format="%s %b" 2>/dev/null || true)
  fi

  # Bump: Feat!: major | Feat: minor | Fix: patch
  BUMP="patch"
  if [[ -n "$FULL_LOG" ]]; then
    if echo "$FULL_LOG" | grep -qiE 'Feat!:|feat!:|BREAKING CHANGE'; then
      BUMP="major"
    elif echo "$FULL_LOG" | grep -qiE 'Feat:|feat:'; then
      BUMP="minor"
    elif echo "$FULL_LOG" | grep -qiE 'Fix:|fix:'; then
      BUMP="patch"
    fi
  fi

  case "$BUMP" in
    major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
    minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
    patch) PATCH=$((PATCH + 1)) ;;
  esac

  NEW_BASE="${MAJOR}.${MINOR}.${PATCH}"
  # Contador de RCs para esta base: v0.2.0-rc, v0.2.0-rc.1, v0.2.0-rc.2...
  RC_COUNT=$(git tag -l "v${NEW_BASE}-rc*" 2>/dev/null | wc -l)
  if [[ "$RC_COUNT" -eq 0 ]]; then
    VERSION="${NEW_BASE}-rc"
  else
    VERSION="${NEW_BASE}-rc.${RC_COUNT}"
  fi
  echo "$VERSION"
  exit 0
fi

# ---------- MAIN: última tag -rc ancestral de HEAD → versão final (sem -rc)
if [[ "$BRANCH" == "main" ]]; then
  LATEST_RC=$(git tag -l 'v*.*.*-rc*' --merged HEAD 2>/dev/null | sort -V | tail -1 || true)
  if [[ -z "$LATEST_RC" ]]; then
    # Sem tag RC (ex.: commit direto em main): não gerar versão semântica
    exit 0
  fi
  VERSION="${LATEST_RC#v}"
  VERSION="${VERSION%-rc*}"
  echo "$VERSION"
  exit 0
fi

# ---------- DEVELOP: última tag ancestral de HEAD (a tag “vem” do merge release → develop)
if [[ "$BRANCH" == "develop" ]]; then
  LATEST_TAG=$(git tag -l 'v*' --merged HEAD 2>/dev/null | sort -V | tail -1 || true)
  if [[ -z "$LATEST_TAG" ]]; then
    exit 0
  fi
  VERSION="${LATEST_TAG#v}"
  echo "$VERSION"
  exit 0
fi

# ---------- Outras branches: sem versão semântica (não falha o step)
exit 0
