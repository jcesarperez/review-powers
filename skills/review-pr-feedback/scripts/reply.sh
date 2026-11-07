#!/usr/bin/env bash
# The write side of review-pr-feedback. Each command posts one thing and prints
# its URL. Bodies come from a file (or `-` for stdin), so backticks and quotes
# survive. Run it only after the user has decided.
#
# Usage:
#   reply.sh inline   <PR> <comment-id> <body-file|->   reply to an inline review comment
#   reply.sh comment  <PR> <body-file|->                post a conversation comment on the PR
#   reply.sh resolve  <thread-id>                       resolve a review thread (id from feeds.md)
#   reply.sh describe <PR> <body-file|->                replace the PR description
# <PR> is a URL, owner/repo#N or N. Comment ids and thread ids are in feeds.md.
# Needs: gh, jq.

set -euo pipefail
SKILL_NAME=review-pr-feedback
# shellcheck source=lib/feeds.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/feeds.sh"

usage() { sed -n '/^# Usage:/,/^# Needs/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2; exit 2; }

need_tools

# body_ref <file|->: the value for gh's -F body=@..., checked early.
body_ref() {
  [ -n "${1:-}" ] || usage
  if [ "$1" = - ]; then BODY_REF=@-; return; fi
  [ -s "$1" ] || die "body file is missing or empty: $1"
  BODY_REF="@$1"
}

# post <what> <gh api args...>: prints the URL, or dies with gh's reason.
post() {
  local what="$1"; shift
  if ! gh api "$@" --jq '.html_url // .url // "done"' >"$TMP/out" 2>"$ERRF"; then
    die "$what failed: $(gh_err)"
  fi
  echo "$what: $(tail -n 1 "$TMP/out")"
}

cmd="${1:-}"; [ $# -gt 0 ] && shift
case "$cmd" in
  inline)
    [ $# -eq 3 ] || usage
    resolve_pr "$1"; body_ref "$3"
    case "$2" in ''|*[!0-9]*) die "comment id must be a number (see feeds.md): $2" ;; esac
    # Replies go to the replies endpoint of the comment; a PR-level comment
    # posted here would 404.
    post "replied to inline comment $2" -X POST "repos/$OWNER/$REPO/pulls/$NUMBER/comments/$2/replies" -F "body=$BODY_REF" ;;
  comment)
    [ $# -eq 2 ] || usage
    resolve_pr "$1"; body_ref "$2"
    post "posted conversation comment on #$NUMBER" -X POST "repos/$OWNER/$REPO/issues/$NUMBER/comments" -F "body=$BODY_REF" ;;
  resolve)
    [ $# -eq 1 ] || usage
    case "$1" in PRRT_*) ;; *) die "thread id should look like PRRT_... (see feeds.md): $1" ;; esac
    if gh api graphql -f query='mutation($id:ID!){resolveReviewThread(input:{threadId:$id}){thread{id isResolved}}}' \
         -f id="$1" --jq '.data.resolveReviewThread.thread | "\(.id) resolved=\(.isResolved)"' >"$TMP/out" 2>"$ERRF"; then
      echo "resolve thread: $(tail -n 1 "$TMP/out")"
    else die "resolve thread failed: $(gh_err)"; fi ;;
  describe)
    [ $# -eq 2 ] || usage
    resolve_pr "$1"; body_ref "$2"
    # REST on purpose: `gh pr edit` goes through GraphQL repository resolution, which fails in some setups.
    post "updated description of #$NUMBER" -X PATCH "repos/$OWNER/$REPO/pulls/$NUMBER" -F "body=$BODY_REF" ;;
  *) usage ;;
esac
