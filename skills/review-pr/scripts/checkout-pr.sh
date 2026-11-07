#!/usr/bin/env bash
# Check a PR out for reading, without touching the user's own checkout: a
# detached worktree at <scratch dir>/worktree, on the PR's head commit. No local
# branch is created, so nothing is left behind except the worktree.
#
# Usage: checkout-pr.sh <PR URL | owner/repo#N | N>            create (or replace) it
#        checkout-pr.sh <PR URL | owner/repo#N | N> --cleanup  remove it; safe to repeat
#   scratch dir: the one fetch-pr.sh uses, so the worktree sits next to the feeds.
#
# Run from inside a clone of the PR's repo (any worktree of it). Prints the path.
# Needs: git, gh, jq.

set -euo pipefail
SKILL_NAME=review-pr
# shellcheck source=lib/feeds.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/feeds.sh"

need_tools
resolve_pr "${1:-}"
MODE="${2:-}"
case "$MODE" in ''|--cleanup) ;; *) die "unknown option: $MODE (only --cleanup)" ;; esac
scratch_dir ""
WT="$OUT/worktree"

# remove_worktree: drops the worktree and its bookkeeping. Idempotent. The repo
# is found from the worktree itself, so this works from any directory.
remove_worktree() {
  local common
  if [ -e "$WT/.git" ]; then
    common="$(git -C "$WT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    if [ -n "$common" ]; then git --git-dir="$common" worktree remove --force "$WT" 2>/dev/null || true; fi
  fi
  [ ! -e "$WT" ] || rm -rf "$WT"
  # Forget worktrees whose directory is gone, including this one's.
  if git rev-parse --git-dir >/dev/null 2>&1; then git worktree prune; fi
  if [ -n "${common:-}" ]; then git --git-dir="$common" worktree prune; fi
}

if [ "$MODE" = --cleanup ]; then
  remove_worktree
  echo "removed worktree for $OWNER/$REPO#$NUMBER"
  exit 0
fi

git rev-parse --git-dir >/dev/null 2>&1 ||
  die "not inside a git repository; run this from a clone of $OWNER/$REPO"

# The remote that points at the PR's repo; origin when none matches by name.
REMOTE=""
while IFS= read -r r; do
  case "$(git remote get-url "$r" 2>/dev/null)" in *"$OWNER/$REPO"*|*"$OWNER/$REPO.git"*) REMOTE="$r"; break ;; esac
done < <(git remote)
if [ -z "$REMOTE" ]; then
  git remote get-url origin >/dev/null 2>&1 ||
    die "no remote for $OWNER/$REPO in this repository; run this from a clone of it"
  REMOTE=origin
fi

remove_worktree   # a stale one from an earlier run would make `worktree add` fail
git fetch -q "$REMOTE" "pull/$NUMBER/head" 2>"$ERRF" ||
  die "cannot fetch pull/$NUMBER/head from $REMOTE: $(gh_err)"
git worktree add -q --detach "$WT" FETCH_HEAD 2>"$ERRF" ||
  die "cannot create the worktree at $WT: $(gh_err)"

echo "PR $OWNER/$REPO#$NUMBER checked out, detached at $(git -C "$WT" rev-parse --short HEAD)"
echo "  $WT"
echo "  remove it when the review ends: $0 $1 --cleanup"
