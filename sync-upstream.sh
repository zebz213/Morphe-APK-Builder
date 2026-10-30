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
set -euo pipefail

UPSTREAM_REMOTE=${UPSTREAM_REMOTE:-upstream}
UPSTREAM_BRANCH=${UPSTREAM_BRANCH:-main}
MERGE=0 PUSH=0

for arg in "$@"; do
  case $arg in
    --merge) MERGE=1 ;;
    --push) MERGE=1; PUSH=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
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

  if [ "$MERGE" = 0 ]; then
    echo "run with --merge to bring these in (or --push to merge and push)."
    exit 0
  fi

  if ! git merge --no-edit "$UP"; then
    echo
    echo "CONFLICTS — resolve these, then 'git add <file>' and 'git commit':"
    git diff --name-only --diff-filter=U | sed 's/^/  /'
    exit 1
  fi
  echo "merged $UP"
fi

if [ "$PUSH" = 1 ]; then
  git push origin "HEAD:$(git rev-parse --abbrev-ref HEAD)"
fi
