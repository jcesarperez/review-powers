#!/usr/bin/env bash
# Feed-fetching code shared by review-pr (fetch-pr.sh) and review-pr-feedback
# (feeds.sh). Each skill folder installs on its own, so this file exists in both
# and must stay byte-identical: edit one, copy to the other, check with
#   cmp skills/review-pr/scripts/lib/feeds.sh skills/review-pr-feedback/scripts/lib/feeds.sh
#
# Sourced, not executed. The caller runs `set -euo pipefail` and sets SKILL_NAME
# (names the default scratch dir). Use: need_tools, resolve_pr, scratch_dir,
# feeds_fetch, feeds_summary.

die() { echo "error: $*" >&2; exit 1; }

# need_tools: checks gh and jq, and makes TMP (private, deleted on exit) and ERRF.
need_tools() {
  command -v gh >/dev/null 2>&1 || die "gh is not installed (https://cli.github.com)"
  command -v jq >/dev/null 2>&1 || die "jq is not installed (https://jqlang.github.io/jq)"
  TMP="$(mktemp -d "${TMPDIR:-/tmp}/review-powers.XXXXXX")" || die "cannot create a temp dir"
  trap cleanup_tmp EXIT
  ERRF="$TMP/stderr"
}
cleanup_tmp() { [ -n "${TMP:-}" ] && [ -d "$TMP" ] && rm -r "$TMP"; return 0; }

# First line of the last gh error, for messages.
gh_err() { head -c 300 "$ERRF" 2>/dev/null | head -n 1; }

# resolve_pr <PR URL | owner/repo#N | N>  ->  OWNER REPO NUMBER
# A bare number means the repo of the current directory.
resolve_pr() {
  local arg="${1:-}" slug rest tail
  [ -n "$arg" ] || die "missing PR: pass a PR URL or number"
  case "$arg" in
    http*://*/*/*/pull/[0-9]*)
      slug="${arg#*://*/}"                 # owner/repo/pull/N[/files...]
      OWNER="${slug%%/*}"; rest="${slug#*/}"
      REPO="${rest%%/*}"; tail="${rest#*/pull/}"
      NUMBER="${tail%%[!0-9]*}" ;;
    */*#[0-9]*)
      OWNER="${arg%%/*}"; rest="${arg#*/}"
      REPO="${rest%%#*}"; NUMBER="${rest#*#}" ;;
    *[!0-9]*) die "not a PR URL or number: $arg" ;;
    *)
      NUMBER="$arg"
      slug="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>"$ERRF")" ||
        die "could not tell which repo PR $arg is in ($(gh_err)); pass the full PR URL"
      OWNER="${slug%%/*}"; REPO="${slug#*/}" ;;
  esac
  case "$NUMBER" in ''|*[!0-9]*) die "no PR number in: $arg" ;; esac
  [ -n "$OWNER" ] && [ -n "$REPO" ] || die "no owner/repo in: $arg"
}

# scratch_dir <explicit dir or empty>  ->  OUT (created)
# Default: ${REVIEW_POWERS_SCRATCH:-${TMPDIR:-/tmp}/review-powers}/<SKILL_NAME>/<repo>-<n>
scratch_dir() {
  local root
  if [ -n "${1:-}" ]; then OUT="$1"
  else
    root="${REVIEW_POWERS_SCRATCH:-${TMPDIR:-/tmp}/review-powers}"
    OUT="${root%/}/${SKILL_NAME:-pr}/$REPO-$NUMBER"
  fi
  mkdir -p "$OUT" || die "cannot create $OUT"
  OUT="$(cd "$OUT" && pwd)"
}

# paged <REST path> <file>: every page of a list endpoint as one JSON array.
paged() {
  gh api --paginate "$1?per_page=100" --jq '.[]' >"$TMP/page.ndjson" 2>"$ERRF" ||
    die "gh api $1 failed: $(gh_err)"
  jq -s '.' "$TMP/page.ndjson" >"$2"
}

# feeds_fetch: needs OWNER REPO NUMBER OUT TMP. Writes into $OUT:
#   inline.json        inline review comments, one object per comment, with its
#                      thread id, is_resolved, outdated, in_reply_to, path, line,
#                      author, is_bot
#   conversation.json  conversation comments
#   reviews.json       review bodies (an inline-only review has an empty body)
#   feeds.md           the three feeds as readable text, threads grouped
# Bodies have HTML comments stripped: bots hide finding metadata and build
# tables in them, and they only cost tokens.
# Sets N_INLINE N_THREADS N_OPEN N_RESOLVED N_OUTDATED N_INLINE_BOT N_CONV
# N_CONV_BOT N_REVIEWS N_REVIEWS_BODY N_REVIEWS_BOT, and FEEDS_WARN if thread
# state could not be read.
feeds_fetch() {
  local api="repos/$OWNER/$REPO" q
  FEEDS_WARN=""

  paged "$api/pulls/$NUMBER/comments" "$TMP/inline.raw"
  paged "$api/issues/$NUMBER/comments" "$TMP/conv.raw"
  paged "$api/pulls/$NUMBER/reviews" "$TMP/reviews.raw"

  # Thread state exists only in GraphQL.
  q='query($owner:String!,$name:String!,$number:Int!,$endCursor:String){repository(owner:$owner,name:$name){pullRequest(number:$number){reviewThreads(first:100,after:$endCursor){pageInfo{hasNextPage endCursor} nodes{id isResolved isOutdated comments(first:100){nodes{databaseId}}}}}}}'
  if gh api graphql --paginate -f query="$q" -f owner="$OWNER" -f name="$REPO" -F number="$NUMBER" \
       --jq '.data.repository.pullRequest.reviewThreads.nodes[]' >"$TMP/threads.ndjson" 2>"$ERRF"; then
    jq -s '.' "$TMP/threads.ndjson" >"$TMP/threads.json"
  else
    FEEDS_WARN="thread state (resolved/outdated) unavailable: $(gh_err)"
    echo '[]' >"$TMP/threads.json"
  fi

  local strip='def strip: (. // "") | gsub("<!--[\\s\\S]*?-->"; "") | gsub("\n{3,}"; "\n\n") | sub("^\\s+"; "") | sub("\\s+$"; "");
    def bot: (.user.type == "Bot") or ((.user.login // "") | endswith("[bot]"));'

  jq --slurpfile t "$TMP/threads.json" "$strip"'
    ($t[0] | reduce .[] as $th ({}; reduce $th.comments.nodes[] as $c (.;
       .[($c.databaseId | tostring)] = {thread_id: $th.id, is_resolved: $th.isResolved, outdated: $th.isOutdated}))) as $m
    | map(. as $c | ($m[($c.id | tostring)] // {}) as $s | {
        id, thread_id: $s.thread_id, is_resolved: $s.is_resolved, outdated: $s.outdated,
        in_reply_to: .in_reply_to_id, path, line: (.line // .original_line),
        author: .user.login, is_bot: bot, created_at, url: .html_url, body: (.body | strip)})' \
    "$TMP/inline.raw" >"$OUT/inline.json"
  jq "$strip"'map({id, author: .user.login, is_bot: bot, created_at, url: .html_url, body: (.body | strip)})' \
    "$TMP/conv.raw" >"$OUT/conversation.json"
  jq "$strip"'map({id, author: .user.login, is_bot: bot, state, submitted_at, url: .html_url, body: (.body | strip)})' \
    "$TMP/reviews.raw" >"$OUT/reviews.json"

  N_INLINE="$(jq length "$OUT/inline.json")"
  N_THREADS="$(jq '[.[] | select(.in_reply_to == null)] | length' "$OUT/inline.json")"
  N_RESOLVED="$(jq '[.[] | select(.in_reply_to == null and .is_resolved == true)] | length' "$OUT/inline.json")"
  N_OUTDATED="$(jq '[.[] | select(.in_reply_to == null and .outdated == true)] | length' "$OUT/inline.json")"
  N_OPEN=$((N_THREADS - N_RESOLVED))
  N_INLINE_BOT="$(jq '[.[] | select(.is_bot)] | length' "$OUT/inline.json")"
  N_CONV="$(jq length "$OUT/conversation.json")"
  N_CONV_BOT="$(jq '[.[] | select(.is_bot)] | length' "$OUT/conversation.json")"
  N_REVIEWS="$(jq length "$OUT/reviews.json")"
  N_REVIEWS_BODY="$(jq '[.[] | select(.body != "")] | length' "$OUT/reviews.json")"
  N_REVIEWS_BOT="$(jq '[.[] | select(.is_bot)] | length' "$OUT/reviews.json")"

  {
    echo "# Feeds for $OWNER/$REPO#$NUMBER"
    echo
    echo "## Inline review comments ($N_INLINE in $N_THREADS threads: $N_OPEN open, $N_RESOLVED resolved, $N_OUTDATED outdated)"
    echo
    jq -r '. as $all | .[] | select(.in_reply_to == null) | . as $root
      | "### thread \(.thread_id // "?") · \(.path):\(.line // "?") · \(if .is_resolved == true then "resolved" elif .is_resolved == false then "open" else "state unknown" end)\(if .outdated then " · outdated" else "" end)",
        ($all | map(select(.id == $root.id or .in_reply_to == $root.id)) | sort_by(.created_at)[]
          | "- id \(.id) · \(.author)\(if .is_bot and (.author | endswith("[bot]") | not) then " [bot]" else "" end)\(if .in_reply_to then " (reply)" else "" end):\n  " + (.body | gsub("\n"; "\n  "))),
        ""' "$OUT/inline.json"
    echo "## Conversation comments ($N_CONV)"
    echo
    jq -r '.[] | "- id \(.id) · \(.author)\(if .is_bot and (.author | endswith("[bot]") | not) then " [bot]" else "" end):\n  " + (.body | gsub("\n"; "\n  "))' "$OUT/conversation.json"
    echo
    echo "## Review bodies ($N_REVIEWS reviews, $N_REVIEWS_BODY with a body)"
    echo
    jq -r '.[] | "- id \(.id) · \(.author)\(if .is_bot and (.author | endswith("[bot]") | not) then " [bot]" else "" end) · \(.state)" + (if .body == "" then " (no body; see inline)" else ":\n  " + (.body | gsub("\n"; "\n  ")) end)' "$OUT/reviews.json"
  } >"$OUT/feeds.md"
}

# feeds_summary: the three feed counts, zero included. An unread feed and an
# empty one look the same otherwise.
feeds_summary() {
  echo "  inline review comments: $N_INLINE in $N_THREADS threads ($N_OPEN open, $N_RESOLVED resolved, $N_OUTDATED outdated; $N_INLINE_BOT from bots)"
  echo "  conversation comments:  $N_CONV ($N_CONV_BOT from bots)"
  echo "  review bodies:          $N_REVIEWS reviews, $N_REVIEWS_BODY with a body ($N_REVIEWS_BOT from bots)"
  [ -z "$FEEDS_WARN" ] || echo "  warning: $FEEDS_WARN"
  return 0
}
