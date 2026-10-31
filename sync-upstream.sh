#!/usr/bin/env bash
# Inspect or pull updates from the `upstream` remote (configure separately if unset).
#
#   ./sync-upstream.sh           show what upstream changed since our last merge
#   ./sync-upstream.sh --merge   merge upstream/main; conflicts are left to you
#   ./sync-upstream.sh --push    merge (if needed) and push to origin
#
# The two repos share history (see the "Join history with upstream" merge), so
# this is a plain three-way merge: local changes are kept and only files that
# both sides touched need manual resolution. Nothing is overwritten wholesale.
#
# PROTECTED files are ours. An upstream edit to one of them either conflicts (so
# it is resolved by hand) or is reported after the merge, so its wording is never
# replaced silently — compare and merge only the parts worth taking.
set -euo pipefail

UPSTREAM_REMOTE=${UPSTREAM_REMOTE:-upstream}
UPSTREAM_BRANCH=${UPSTREAM_BRANCH:-main}
PROTECTED=(config.toml README.md)
MERGE=0 PUSH=0

for arg in "$@"; do
  case $arg in
    --merge) MERGE=1 ;;
    --push) MERGE=1; PUSH=1 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

cd "$(git rev-parse --show-toplevel)"
git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1 ||
  { echo "remote '$UPSTREAM_REMOTE' not configured" >&2; exit 1; }
git fetch --quiet "$UPSTREAM_REMOTE"
UP="$UPSTREAM_REMOTE/$UPSTREAM_BRANCH"

if ! git merge-base HEAD "$UP" >/dev/null 2>&1; then
  echo "no common history with $UP — the ancestor merge is missing" >&2
  exit 1
fi

if git merge-base --is-ancestor "$UP" HEAD; then
  echo "already up to date with $UP ($(git rev-parse --short "$UP"))"
else
  base=$(git merge-base HEAD "$UP")
  echo "upstream commits not merged yet:"
  git --no-pager log --oneline "HEAD..$UP" | sed 's/^/  /' | head -40
  echo
  echo "files upstream changed since ${base:0:7}:"
  git --no-pager diff --stat "$base" "$UP" | sed 's/^/  /'
  echo
  echo "protected files upstream touched:"
  touched=0
  for f in "${PROTECTED[@]}"; do
    if ! git diff --quiet "$base" "$UP" -- "$f"; then
      echo "  $f   (compare: git diff ${base:0:7}..$UP -- $f)"
      touched=1
    fi
  done
  [ "$touched" = 1 ] || echo "  none"
  echo

  if [ "$MERGE" = 0 ]; then
    echo "run with --merge to bring these in (or --push to merge and push)."
    exit 0
  fi

  PRE_MERGE=$(git rev-parse HEAD)
  if ! git merge --no-edit "$UP"; then
    echo
    echo "CONFLICTS — resolve these, then 'git add <file>' and 'git commit':"
    git diff --name-only --diff-filter=U | sed 's/^/  /'
    exit 1
  fi
  echo "merged $UP"
  for f in "${PROTECTED[@]}"; do
    if ! git diff --quiet "$PRE_MERGE" HEAD -- "$f"; then
      echo "  note: '$f' changed in this merge — review before pushing:"
      echo "        git diff ${PRE_MERGE:0:7} HEAD -- $f"
    fi
  done
fi

if [ "$PUSH" = 1 ]; then
  git push origin "HEAD:$(git rev-parse --abbrev-ref HEAD)"
fi
