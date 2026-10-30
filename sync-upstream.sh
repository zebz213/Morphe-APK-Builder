#!/usr/bin/env bash
# Re-sync this repo with upstream j-hc/revanced-magisk-module, keeping local changes.
#
#   ./sync-upstream.sh             sync and commit
#   ./sync-upstream.sh --push      sync, commit and push to origin
#   ./sync-upstream.sh --dry-run   only show what upstream changed
#   ./sync-upstream.sh --yes       overwrite unprotected local edits without asking
#
# Anything listed in PROTECTED below is never overwritten or deleted.
# This repo is not a git fork (it started as an uploaded snapshot), so a normal
# `git pull` cannot be used; this script applies upstream's tree wholesale.
set -euo pipefail

UPSTREAM_REMOTE=${UPSTREAM_REMOTE:-upstream}
UPSTREAM_BRANCH=${UPSTREAM_BRANCH:-main}

# ---- files kept across syncs -----------------------------------------
PROTECTED=(
  config.toml       # app selection, patch sources, brands
  sync-upstream.sh  # this script (not part of upstream)
)
# ----------------------------------------------------------------------

# ---- upstream files that get local tweaks after every sync -----------
# Follow upstream normally, then `apply_tweaks` below rewrites them.
REGENERATED=(
  README.md         # badges must point at this repo, not j-hc's
)
# ----------------------------------------------------------------------

PUSH=0 YES=0 DRY=0
for arg in "$@"; do
  case $arg in
    --push) PUSH=1 ;;
    --yes|-y) YES=1 ;;
    --dry-run) DRY=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

cd "$(git rev-parse --show-toplevel)"
git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1 ||
  { echo "remote '$UPSTREAM_REMOTE' not configured" >&2; exit 1; }

git fetch --quiet "$UPSTREAM_REMOTE"
UP="$UPSTREAM_REMOTE/$UPSTREAM_BRANCH"
UP_SHA=$(git rev-parse --short "$UP")

if [ "$DRY" = 1 ]; then
  echo "upstream $UP @ $UP_SHA — differs from HEAD in:"
  git --no-pager diff --stat "HEAD..$UP"
  exit 0
fi

git diff --quiet && git diff --cached --quiet ||
  { echo "working tree is dirty — commit or stash first" >&2; exit 1; }

is_protected() {
  local f=$1 p
  for p in "${PROTECTED[@]}"; do
    [ "$f" = "$p" ] && return 0
    case $f in "$p"/*) return 0 ;; esac
  done
  return 1
}

is_regenerated() {
  local f=$1 p
  for p in "${REGENERATED[@]}"; do
    [ "$f" = "$p" ] && return 0
  done
  return 1
}

# Refuse to silently drop commits that touched unprotected files since the last sync.
base=$(git log -1 --format=%H --grep '^Sync with upstream' 2>/dev/null || true)
dropped=()
if [ -n "$base" ]; then
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    is_protected "$f" || is_regenerated "$f" || dropped+=("$f")
  done < <(git diff --name-only "$base" HEAD)
fi
if [ ${#dropped[@]} -gt 0 ] && [ "$YES" = 0 ]; then
  echo "These files were changed locally since the last sync and are NOT protected:"
  printf '  %s\n' "${dropped[@]}"
  echo
  echo "Add them to PROTECTED above, or re-run with --yes to let upstream win."
  exit 1
fi

backup=$(mktemp -d)
trap 'rm -rf "$backup"' EXIT
for p in "${PROTECTED[@]}"; do
  [ -e "$p" ] || continue
  mkdir -p "$backup/$(dirname "$p")"
  cp -a "$p" "$backup/$p"
done

git read-tree -u --reset "$UP"

for p in "${PROTECTED[@]}"; do
  [ -e "$backup/$p" ] || continue
  rm -rf -- "$p"
  cp -a "$backup/$p" "$p"
  git add -- "$p"
done

# Local tweaks re-applied on top of the freshly synced upstream files.
apply_tweaks() {
  local f
  for f in "${REGENERATED[@]}"; do
    [ -f "$f" ] || continue
    case $f in
      README.md)
        sed -i \
          -e 's#https://github\.com/j-hc/revanced-magisk-module#https://github.com/zebz213/revanced-apk#g' \
          -e 's#https://raw\.githubusercontent\.com/j-hc/revanced-magisk-module#https://raw.githubusercontent.com/zebz213/revanced-apk#g' \
          -e 's#cd revanced-magisk-module#cd revanced-apk#g' \
          "$f"
        ;;
    esac
    git add -- "$f"
  done
}
apply_tweaks

find . -mindepth 1 -type d -empty -not -path './.git/*' -print0 2>/dev/null |
  xargs -0 -r rmdir 2>/dev/null || true

if git diff --cached --quiet; then
  echo "already up to date with $UP ($UP_SHA)"
  exit 0
fi

git commit --quiet -m "Sync with upstream $UP @ $UP_SHA

Applied upstream content wholesale; kept local versions of: ${PROTECTED[*]}
Re-applied local tweaks to: ${REGENERATED[*]}"
echo "synced to $UP @ $UP_SHA"
git --no-pager log --oneline -1

if [ "$PUSH" = 1 ]; then
  git push origin "HEAD:$(git rev-parse --abbrev-ref HEAD)"
fi
