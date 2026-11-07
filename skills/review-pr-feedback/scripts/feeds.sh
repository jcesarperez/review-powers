#!/usr/bin/env bash
# Fetch a PR's review feedback into a scratch dir, and print a short summary
# (counts per feed, zero included, and whether you are on the PR's head commit).
# It never prints the feedback itself; read the files you need.
#
# Usage: feeds.sh <PR URL | owner/repo#N | N> [scratch-dir]
#   scratch dir default: ${REVIEW_POWERS_SCRATCH:-${TMPDIR:-/tmp}/review-powers}/review-pr-feedback/<repo>-<n>
#
# Writes: head.json, feeds.md (all three feeds, threads grouped, comment and
#   thread ids), inline.json, conversation.json, reviews.json.
# Needs: gh, jq.

set -euo pipefail
SKILL_NAME=review-pr-feedback
# shellcheck source=lib/feeds.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/feeds.sh"

need_tools
resolve_pr "${1:-}"
scratch_dir "${2:-}"
REPO_SLUG="$OWNER/$REPO"

gh pr view "$NUMBER" -R "$REPO_SLUG" --json number,title,state,author,headRefName,headRefOid,url \
  >"$TMP/pr.json" 2>"$ERRF" || die "cannot read PR $REPO_SLUG#$NUMBER: $(gh_err)"
PR_SHA="$(jq -r .headRefOid "$TMP/pr.json")"
PR_BRANCH="$(jq -r .headRefName "$TMP/pr.json")"

# A file:line in a comment points at the PR head. Compare with what is checked out.
LOCAL_SHA=""; LOCAL_BRANCH=""
if git rev-parse --git-dir >/dev/null 2>&1; then
  LOCAL_SHA="$(git rev-parse HEAD 2>/dev/null || true)"
  LOCAL_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
fi
if [ -z "$LOCAL_SHA" ]; then MATCH=null
elif [ "$LOCAL_SHA" = "$PR_SHA" ]; then MATCH=true
else MATCH=false; fi
jq --arg local "$LOCAL_SHA" --arg lb "$LOCAL_BRANCH" --argjson match "$MATCH" \
  '{number, title, state, author: .author.login, url, pr_branch: .headRefName, pr_head_sha: .headRefOid,
    local_head_sha: (if $local == "" then null else $local end), local_branch: (if $lb == "" then null else $lb end),
    head_matches: $match}' "$TMP/pr.json" >"$OUT/head.json"

feeds_fetch

echo "PR $REPO_SLUG#$NUMBER ($(jq -r .state "$TMP/pr.json")), author $(jq -r .author.login "$TMP/pr.json")"
case "$MATCH" in
  true)  echo "  head: PR ${PR_SHA:0:7}, local ${LOCAL_SHA:0:7}, match (branch $LOCAL_BRANCH)" ;;
  false) echo "  head: PR ${PR_SHA:0:7} ($PR_BRANCH), local ${LOCAL_SHA:0:7} ($LOCAL_BRANCH), MISMATCH: file:line in the comments may not match your tree; check out the PR head first" ;;
  *)     echo "  head: PR ${PR_SHA:0:7} ($PR_BRANCH), no local git checkout here, so nothing to compare" ;;
esac
echo "  feeds:"
feeds_summary
echo "wrote to $OUT:"
echo "  feeds.md inline.json conversation.json reviews.json head.json"
