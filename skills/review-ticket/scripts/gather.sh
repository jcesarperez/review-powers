#!/usr/bin/env bash
# Gather everything a ticket review starts from into a scratch dir: the Jira
# ticket and its subtasks, every PR whose title or branch names one of their
# keys, each PR's comment feeds, and, per repo, the code at its default branch
# plus the list of AI context files (CLAUDE.md, AGENTS.md, rules) that apply to
# what the PRs touched. Prints an index (paths, counts, failures), never content.
#
# Usage: gather.sh [--owner <github owner>] [--repos-dir <dir>]... <KEY | Jira URL> [out-dir]
#        gather.sh --cleanup <out-dir>        remove the code trees; safe to repeat
#        gather.sh context <tree> <files>     the AI context that applies to <files>
#                                             (one repo-relative path per line) in <tree>
#   --owner      search PRs only in this GitHub user or org; default: every repo
#                you can see, keeping PRs whose title or branch names the key
#   --repos-dir  where local clones live (repeatable); the parent of the current
#                repo and the current dir are always searched. A repo with no
#                local clone is shallow-cloned into the out dir.
#   out dir default: ${REVIEW_POWERS_SCRATCH:-${TMPDIR:-/tmp}/review-powers}/review-ticket/<KEY>
#
# Writes: index.md (what it prints), jira/<KEY>.md, prs/<repo>-<n>/{pr.md,
#   pr.json, feeds.md, inline.json, conversation.json, reviews.json},
#   repos/<owner>-<repo>/{tree/, context.tsv, context.md, touched.txt}.
# Failures are listed in the index instead of aborting, so a partial gather is
# still usable; only an unreadable ticket stops it.
# Needs: gh, jq, git, acli (Atlassian CLI, logged in).

set -euo pipefail
SKILL_NAME=review-ticket
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/feeds.sh
. "$HERE/lib/feeds.sh"

TAB="$(printf '\t')"

# Waits between GitHub searches (30 a minute) and on rate limits. Tests turn them off.
nap() { [ -n "${REVIEW_TICKET_NO_WAIT:-}" ] || sleep "$1"; }

note_err() { printf '%s\n' "$*" >>"$TMP/errors"; }

# retry_gh <out-file> <gh args...>: gh, retried with backoff when rate-limited.
retry_gh() {
  local out="$1" d
  shift
  for d in 5 10 20 25 0; do
    if gh "$@" >"$out" 2>"$ERRF"; then return 0; fi
    [ "$d" != 0 ] || return 1
    grep -qiE 'rate limit|secondary rate|abuse detection|http 403|http 429' "$ERRF" || return 1
    nap "$d"
  done
}

# has_key <text> <KEY>: the text names the key, case-insensitive, as a whole key
# (ABC-12 is not named by "ABC-123"). Branches are usually lowercase.
has_key() {
  printf '%s' "$1" | tr '[:lower:]' '[:upper:]' | grep -qE "(^|[^A-Z0-9])$2([^0-9]|$)"
}

# --- AI context ----------------------------------------------------------------

# expand_braces <glob>: one line per alternative of every {a,b} group.
expand_braces() {
  local p="$1" pre rest mid post alt
  local -a alts
  case "$p" in *'{'*'}'*) ;; *) printf '%s\n' "$p"; return 0 ;; esac
  pre="${p%%\{*}"; rest="${p#*\{}"; mid="${rest%%\}*}"; post="${rest#*\}}"
  IFS=, read -r -a alts <<<"$mid"
  for alt in "${alts[@]}"; do expand_braces "$pre$alt$post"; done
}

# glob_match <path> <glob>: gitignore-style enough for rule paths. In [[ == ]] a
# `*` also crosses `/`, so `**` works; `**/` may also stand for no directory.
glob_match() {
  local f="$1" g alt
  while IFS= read -r g; do
    alt="${g//\*\*\//}"
    # shellcheck disable=SC2053
    if [[ $f == $g ]] || [[ $f == $alt ]]; then return 0; fi
  done < <(expand_braces "$2")
  return 1
}

# rule_paths <rule.md>: its frontmatter `paths:` globs, one per line, or nothing
# when it has none. Handles a YAML list or an inline (comma-separated or [..]) value.
rule_paths() {
  awk '
    function unq(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); gsub(/^["'"'"']|["'"'"']$/, "", s); return s }
    function inline(v,   i, c, depth, cur) {
      gsub(/^[[:space:]]*\[|\][[:space:]]*$/, "", v)
      depth = 0; cur = ""
      for (i = 1; i <= length(v); i++) {
        c = substr(v, i, 1)
        if (c == "{") depth++
        if (c == "}") depth--
        if (c == "," && depth == 0) { if (unq(cur) != "") print unq(cur); cur = "" } else cur = cur c
      }
      if (unq(cur) != "") print unq(cur)
    }
    NR == 1 && $0 !~ /^---[[:space:]]*$/ { exit }
    NR == 1 { fm = 1; next }
    fm && /^---[[:space:]]*$/ { exit }
    fm && /^paths:/ { inp = 1; v = $0; sub(/^paths:[[:space:]]*/, "", v); if (v != "") { inline(v); inp = 0 }; next }
    fm && inp && /^[[:space:]]*-/ { v = $0; sub(/^[[:space:]]*-[[:space:]]*/, "", v); if (unq(v) != "") print unq(v); next }
    fm && inp && /^[^[:space:]]/ { inp = 0 }
  ' "$1"
}

# imports_of <file>: the @path imports it makes (Claude Code syntax), outside
# code blocks and code spans.
imports_of() {
  awk '
    /^[[:space:]]*```/ { inf = !inf; next }
    inf { next }
    { line = $0; gsub(/`[^`]*`/, "", line)
      n = split(line, w, /[[:space:]]+/)
      for (i = 1; i <= n; i++) if (w[i] ~ /^@[^@[:space:]]/) { p = substr(w[i], 2); sub(/[.,;:)]+$/, "", p); print p } }
  ' "$1"
}

# resolve_context <tree> <files>: TSV lines `read|skip <path> <reason>`, paths
# relative to the tree. Order: root files, nearest nested files, rules that
# apply, then what those import; rules that don't apply last, as `skip`.
resolve_context() {
  local t f d name p hit g n rel base target acc skips i total
  t="$(cd "$1" && pwd -P)"
  acc="$(mktemp "${TMPDIR:-/tmp}/review-ticket-ctx.XXXXXX")"
  skips="$acc.skip"
  : >"$skips"

  for name in CLAUDE.md AGENTS.md .claude/CLAUDE.md; do
    [ ! -f "$t/$name" ] || printf 'read\t%s\troot\n' "$name" >>"$acc"
  done

  # Nested CLAUDE.md / AGENTS.md in the directories above each touched file.
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    d="$(dirname "$f")"
    while [ "$d" != "." ] && [ "$d" != "/" ]; do
      for name in CLAUDE.md AGENTS.md; do
        [ ! -f "$t/$d/$name" ] || printf '%s\t%s\n' "$d/$name" "$d"
      done
      d="$(dirname "$d")"
    done
  done < <(sort -u "$2") | sort | uniq -c | while read -r n rel; do
    d="${rel#*"$TAB"}"; rel="${rel%%"$TAB"*}"
    if [ "$n" = 1 ]; then printf 'read\t%s\tcovers %s/ (1 touched file)\n' "$rel" "$d"
    else printf 'read\t%s\tcovers %s/ (%s touched files)\n' "$rel" "$d" "$n"; fi
  done >>"$acc"

  # Rules: a rule without paths applies to every file.
  if [ -d "$t/.claude/rules" ]; then
    while IFS= read -r p; do
      rel="${p#"$t"/}"
      if [ -z "$(rule_paths "$p")" ]; then
        printf 'read\t%s\trule without paths: applies to every file\n' "$rel" >>"$acc"; continue
      fi
      hit=""
      while IFS= read -r g; do
        while IFS= read -r f; do
          [ -n "$f" ] || continue
          if glob_match "$f" "$g"; then hit="rule paths: $g matches $f"; break; fi
        done < <(sort -u "$2")
        [ -z "$hit" ] || break
      done < <(rule_paths "$p")
      if [ -n "$hit" ]; then printf 'read\t%s\t%s\n' "$rel" "$hit" >>"$acc"
      else printf 'skip\t%s\trule paths: %s match no touched file\n' "$rel" "$(rule_paths "$p" | paste -sd ' ' -)" >>"$skips"; fi
    done < <(find "$t/.claude/rules" -type f -name '*.md' | LC_ALL=C sort)
  fi

  # Imports, transitively, from every file read so far.
  i=1
  total="$(wc -l <"$acc" | tr -d ' ')"
  while [ "$i" -le "$total" ]; do
    rel="$(sed -n "${i}p" "$acc" | cut -f2)"
    base="$(dirname "$rel")"
    while IFS= read -r p; do
      case "$p" in '~'*|/*|'') continue ;; esac
      [ -f "$t/$base/$p" ] || continue
      target="$(cd "$(dirname "$t/$base/$p")" && pwd -P)/$(basename "$p")"
      case "$target" in "$t"/*) target="${target#"$t"/}" ;; *) continue ;; esac
      cut -f2 "$acc" | grep -qxF "$target" || printf 'read\t%s\timported by %s\n' "$target" "$rel" >>"$acc"
    done < <(imports_of "$t/$rel")
    i=$((i + 1))
    total="$(wc -l <"$acc" | tr -d ' ')"
  done

  cat "$acc" "$skips"
  rm -f "$acc" "$skips"
}

if [ "${1:-}" = context ]; then
  [ -d "${2:-}" ] && [ -f "${3:-}" ] || die "usage: gather.sh context <tree> <files>"
  resolve_context "$2" "$3"
  exit 0
fi

# --- arguments -----------------------------------------------------------------

GH_OWNER="" CLEANUP="" ARG="" OUT_ARG=""
REPOS_DIRS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --owner) GH_OWNER="${2:?--owner needs a value}"; shift ;;
    --repos-dir) REPOS_DIRS="$REPOS_DIRS${REPOS_DIRS:+$TAB}${2:?--repos-dir needs a value}"; shift ;;
    --cleanup) CLEANUP=1 ;;
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
    -*) die "unknown option: $1" ;;
    *) if [ -z "$ARG" ] && [ -z "$CLEANUP" ]; then ARG="$1"; else OUT_ARG="$1"; fi ;;
  esac
  shift
done

# --- cleanup -------------------------------------------------------------------

if [ -n "$CLEANUP" ]; then
  OUT="${ARG:-$OUT_ARG}"
  [ -n "$OUT" ] && [ -d "$OUT" ] || die "usage: gather.sh --cleanup <out-dir>"
  for src in "$OUT"/repos/*/source; do
    [ -f "$src" ] || continue
    dir="$(dirname "$src")"
    clone="$(cat "$src")"
    if [ -n "$clone" ] && [ -d "$clone" ]; then
      git -C "$clone" worktree remove --force "$dir/tree" 2>/dev/null || true
      git -C "$clone" worktree prune 2>/dev/null || true
    fi
    rm -rf "$dir/tree"
    echo "removed $dir/tree"
  done
  exit 0
fi

# The last key-like match: in a URL the host can look like one (jira-1.example.com).
KEY="$(printf '%s' "$ARG" | tr '[:lower:]' '[:upper:]' | grep -oE '[A-Z][A-Z0-9]+-[0-9]+' | tail -n 1 || true)"
[ -n "$KEY" ] || die "no Jira key in '${ARG}': pass a key like ABC-123 or a ticket URL"

need_tools
command -v acli >/dev/null 2>&1 || die "acli is not installed (https://developer.atlassian.com/cloud/acli)"
command -v git >/dev/null 2>&1 || die "git is not installed"
: >"$TMP/errors"

if [ -n "$OUT_ARG" ]; then OUT="$OUT_ARG"
else OUT="${REVIEW_POWERS_SCRATCH:-${TMPDIR:-/tmp}/review-powers}"; OUT="${OUT%/}/review-ticket/$KEY"; fi
mkdir -p "$OUT/jira" "$OUT/prs" "$OUT/repos" || die "cannot create $OUT"
OUT="$(cd "$OUT" && pwd)"

# --- Jira ----------------------------------------------------------------------

JQ_LIB='
def tidy: gsub("\n[ \t]+(?=\n)"; "\n") | gsub("\n{3,}"; "\n\n") | sub("^\\s+"; "") | sub("\\s+$"; "");
def adf:
  if . == null then ""
  elif type == "string" then .
  elif type == "array" then map(adf) | join("")
  else
    (.attrs // {}) as $a
    | ((.content // []) | map(adf) | join("")) as $in
    | if .type == "text" then (.text // "")
      elif .type == "hardBreak" then "\n"
      elif .type == "mention" or .type == "emoji" then ($a.text // $a.shortName // "")
      elif .type == "inlineCard" or .type == "blockCard" or .type == "embedCard" then ($a.url // "")
      elif .type == "heading" then ("#" * ($a.level // 2)) + " " + $in + "\n\n"
      elif .type == "codeBlock" then "```\n" + $in + "\n```\n\n"
      elif .type == "listItem" then "- " + ($in | gsub("\n\n+"; "\n") | sub("\\s+$"; "") | gsub("\n"; "\n  ")) + "\n"
      elif .type == "taskItem" then "- [" + (if $a.state == "DONE" then "x" else " " end) + "] " + ($in | sub("\\s+$"; "") | gsub("\n"; "\n  ")) + "\n"
      elif .type == "bulletList" or .type == "orderedList" or .type == "taskList" then $in + "\n"
      elif .type == "paragraph" or .type == "blockquote" or .type == "panel" then $in + "\n\n"
      elif .type == "tableRow" then "| " + ((.content // []) | map(adf | tidy) | join(" | ")) + " |\n"
      elif .type == "rule" then "---\n\n"
      else $in end
  end;'

# fetch_issue <KEY>: $TMP/issue-<KEY>.json holds its fields; 1 when unreadable.
fetch_issue() {
  acli jira workitem view "$1" --fields '*all' --json >"$TMP/raw-$1.json" 2>"$ERRF" ||
    { note_err "acli jira workitem view $1: $(gh_err)"; return 1; }
  jq -e '.fields' "$TMP/raw-$1.json" >"$TMP/issue-$1.json" 2>/dev/null ||
    { note_err "acli jira workitem view $1: no fields in its output"; return 1; }
}

write_issue() {
  jq -r --arg k "$1" "$JQ_LIB"'
    "# \($k) — \(.summary // "")",
    "type: \(.issuetype.name // "-") · status: \(.status.name // "-") · assignee: \(.assignee.displayName // "-")",
    (if .parent then "parent: \(.parent.key) (\(.parent.fields.issuetype.name // "-")) — \(.parent.fields.summary // "")" else empty end),
    ((.issuelinks // [])[] | (if .outwardIssue then [.type.outward, .outwardIssue] else [.type.inward, .inwardIssue] end) as [$rel, $o]
      | "link: \($rel) \($o.key) — \($o.fields.summary // "")"),
    (if ((.subtasks // []) | length) > 0 then "subtasks: " + (.subtasks | map("\(.key) [\(.fields.status.name // "-")]") | join(", ")) else empty end),
    "", "## Description", "", (.description | adf | tidy | if . == "" then "(empty)" else . end), "",
    ((.comment.comments // []) as $c | "## Comments (\($c | length))", "",
      ($c[] | "### \(.author.displayName // "?") · \((.created // "")[0:10])", "", (.body | adf | tidy), ""))
  ' "$TMP/issue-$1.json" >"$OUT/jira/$1.md"
}

fetch_issue "$KEY" || die "cannot read the ticket $KEY: $(tail -n 1 "$TMP/errors")"
KEYS="$KEY $(jq -r '(.subtasks // [])[].key' "$TMP/issue-$KEY.json" | tr '\n' ' ')"

{
  echo "Ticket $KEY: $(jq -r '"\(.summary) [\(.status.name // "-")]"' "$TMP/issue-$KEY.json")"
  echo
  echo "Jira:"
  for k in $KEYS; do
    if [ "$k" = "$KEY" ] || fetch_issue "$k"; then
      write_issue "$k"
      echo "  $OUT/jira/$k.md  $(jq -r '"[\(.status.name // "-")] \(.summary)"' "$TMP/issue-$k.json")"
    else
      echo "  $k: FAILED (see Failed)"
    fi
  done
} >"$OUT/index.md"

# --- PRs -----------------------------------------------------------------------

# search_prs <KEY>: appends `key slug number state own|mention title` to
# $TMP/prs.tsv and prints a status line when the key has no PR or the search failed.
search_prs() {
  local key="$1" slug n state title kind failed=""
  # Quoted, the key is one phrase; bare, GitHub matches "ABC" and "123" anywhere.
  set -- search prs "\"$key\"" --limit 50 --json repository,number,title,state
  [ -z "$GH_OWNER" ] || set -- "$@" --owner "$GH_OWNER"
  if ! retry_gh "$TMP/search.json" "$@"; then
    note_err "gh search prs $key: $(gh_err)"
    echo "  $key: search FAILED ($(gh_err)) — not checked"
    return 0
  fi
  jq -r '.[] | [.repository.nameWithOwner, .number, .state, .title] | @tsv' "$TMP/search.json" >"$TMP/hits.tsv"
  # Search is full-text: a PR whose title or branch names the key belongs to
  # it; one that only mentions the key in its body may just reference it.
  while IFS="$TAB" read -r slug n state title <&3; do
    if has_key "$title" "$key"; then kind=own
    elif retry_gh "$TMP/head" pr view "$n" -R "$slug" --json headRefName -q .headRefName; then
      if has_key "$(cat "$TMP/head")" "$key"; then kind=own; else kind=mention; fi
    else
      note_err "gh pr view $slug#$n: $(gh_err)"
      failed="branch lookup failed for $slug#$n"; kind=mention
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$key" "$slug" "$n" "$state" "$kind" "$title" >>"$TMP/prs.tsv"
  done 3<"$TMP/hits.tsv"
  if [ -n "$failed" ]; then echo "  $key: search PARTIALLY failed ($failed) — list may be incomplete"
  elif ! grep -q "^$key$TAB.*${TAB}own$TAB" "$TMP/prs.tsv" 2>/dev/null; then echo "  $key: none found"; fi
}

# fetch_pr <slug> <number> <key>: pr.md, pr.json and the feeds into prs/<repo>-<n>/.
# Prints the index line.
fetch_pr() {
  local slug="$1" n="$2" key="$3" dir counts
  dir="$OUT/prs/${slug#*/}-$n"
  mkdir -p "$dir"
  if ! retry_gh "$dir/pr.json" pr view "$n" -R "$slug" \
       --json number,title,url,state,mergedAt,baseRefName,headRefName,body,files,author; then
    note_err "gh pr view $slug#$n: $(gh_err)"
    echo "  $key  $slug#$n -> FAILED"
    return 0
  fi
  jq -r --arg slug "$slug" "$JQ_LIB"'
    "# \($slug)#\(.number) — \(.title)", .url,
    "state: \(.state) · merged: \(.mergedAt // "-") · \(.headRefName) → \(.baseRefName) · author: \(.author.login // "-")",
    "", "## Description", "", ((.body // "") | gsub("<!--[\\s\\S]*?-->"; "") | tidy | if . == "" then "(empty)" else . end), "",
    "## Files (\(.files | length))", "",
    (.files[] | "- \(.path) (+\(.additions)/-\(.deletions))"),
    "", "Review comments and thread state: feeds.md"' "$dir/pr.json" >"$dir/pr.md"
  jq -r '.files[].path' "$dir/pr.json" >>"$TMP/touched-${slug%%/*}-${slug#*/}"
  printf '%s\n' "$slug" >>"$TMP/repos"

  # feeds_fetch dies on a failed call; a subshell keeps that to this PR.
  if counts="$( (OWNER="${slug%%/*}" REPO="${slug#*/}" NUMBER="$n" OUT="$dir"
                feeds_fetch
                echo "review threads: $N_THREADS ($N_OPEN open), conversation: $N_CONV, review bodies: $N_REVIEWS_BODY${FEEDS_WARN:+; $FEEDS_WARN}") 2>"$TMP/feed-err")"; then
    echo "  $key  $slug#$n [$(jq -r .state "$dir/pr.json")] $(jq -r .title "$dir/pr.json")"
    echo "      $dir  ($counts)"
  else
    note_err "feeds of $slug#$n: $(head -n 1 "$TMP/feed-err")"
    echo "  $key  $slug#$n [$(jq -r .state "$dir/pr.json")] $(jq -r .title "$dir/pr.json")"
    echo "      $dir  (feeds FAILED; description and files only)"
  fi
}

: >"$TMP/prs.tsv"
: >"$TMP/repos"
{
  echo
  echo "PRs (key in title or branch):"
  first=1
  for k in $KEYS; do
    [ -n "$first" ] || nap 2.5   # GitHub search allows 30 requests a minute
    first=""
    search_prs "$k"
  done
  # Each PR once, under the first key that owns it.
  awk -F "$TAB" '$5 == "own" && !seen[$2 "#" $3]++' "$TMP/prs.tsv" | LC_ALL=C sort -t "$TAB" -k2,2 -k3,3n >"$TMP/own.tsv"
  while IFS="$TAB" read -r k slug n _ <&4; do fetch_pr "$slug" "$n" "$k"; done 4<"$TMP/own.tsv"

  # Mentions from an owner with no PR of the ticket are noise from other
  # projects; dropped, and counted.
  awk -F "$TAB" -v drops="$TMP/dropped" '
    NR == FNR { own[$2 "#" $3] = 1; split($2, o, "/"); owners[o[1]] = 1; n++; next }
    $5 == "mention" && !own[$2 "#" $3] && !seen[$2 "#" $3]++ {
      split($2, o, "/"); if (n && !owners[o[1]]) { d++; next }; print }
    END { print d + 0 > drops }' "$TMP/own.tsv" "$TMP/prs.tsv" >"$TMP/mentions.tsv"
  if [ -s "$TMP/mentions.tsv" ]; then
    echo
    echo "Only mentioned in a PR body (not fetched; may or may not belong):"
    while IFS="$TAB" read -r k slug n state _ title; do echo "  $k  $slug#$n [$state] $title"; done <"$TMP/mentions.tsv"
  fi
  if [ "$(cat "$TMP/dropped")" != 0 ]; then
    echo
    echo "Dropped $(cat "$TMP/dropped") search hits from owners with no PR of this ticket."
  fi

  if [ -z "$GH_OWNER" ]; then
    owners="$(cut -f2 "$TMP/own.tsv" | cut -d/ -f1 | sort | uniq -c | sort -rn | awk '{printf "%s%s: %s", (NR > 1 ? ", " : ""), $2, $1}')"
    if [ "$(cut -f2 "$TMP/own.tsv" | cut -d/ -f1 | sort -u | wc -l | tr -d ' ')" -gt 1 ]; then
      echo
      echo "PRs per owner: $owners. Rerun with --owner if some don't belong."
    fi
  fi
} >>"$OUT/index.md"

# --- repos: code and AI context ------------------------------------------------

# norm_remote <url>: owner/repo in lowercase, for any GitHub URL form.
norm_remote() {
  printf '%s' "$1" | sed -E 's#\.git/?$##; s#/$##; s#^.*[:/]([^/:]+/[^/:]+)$#\1#' | tr '[:upper:]' '[:lower:]'
}

# find_clone <slug>: prints `<dir><TAB><remote>` for a local clone with a
# remote pointing at the repo. Raw remote URLs (no insteadOf rewriting).
find_clone() {
  local want dirs top d c line name url
  want="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  dirs="$REPOS_DIRS"
  if top="$(git rev-parse --show-toplevel 2>/dev/null)"; then dirs="$dirs${dirs:+$TAB}$(dirname "$top")"; fi
  dirs="$dirs${dirs:+$TAB}$PWD"
  while IFS= read -r d; do
    [ -d "$d" ] || continue
    for c in "$d" "$d"/*; do
      [ -e "$c/.git" ] || continue
      while IFS= read -r line; do
        name="${line#remote.}"; name="${name%%.url *}"; url="${line#* }"
        if [ "$(norm_remote "$url")" = "$want" ]; then printf '%s\t%s\n' "$c" "$name"; return 0; fi
      done < <(git -C "$c" config --get-regexp '^remote\..*\.url$' 2>/dev/null || true)
    done
  done < <(printf '%s\n' "$dirs" | tr "$TAB" '\n')
  return 1
}

# setup_repo <slug>: repos/<owner>-<repo>/tree at the default branch, and its
# context. Prints the index lines.
setup_repo() {
  local slug="$1" dir branch found clone remote how sha nread nskip
  dir="$OUT/repos/${slug%%/*}-${slug#*/}"
  mkdir -p "$dir"
  sort -u "$TMP/touched-${slug%%/*}-${slug#*/}" >"$dir/touched.txt"
  if ! retry_gh "$TMP/branch" repo view "$slug" --json defaultBranchRef --jq .defaultBranchRef.name; then
    note_err "gh repo view $slug: $(gh_err)"
    echo "  $slug: FAILED (default branch unknown; no code, no context)"
    return 0
  fi
  branch="$(cat "$TMP/branch")"

  # A tree from an earlier run would make the checkout fail.
  if [ -f "$dir/source" ] && [ -n "$(cat "$dir/source")" ]; then
    git -C "$(cat "$dir/source")" worktree remove --force "$dir/tree" 2>/dev/null || true
  fi
  rm -rf "$dir/tree"
  : >"$dir/source"

  if found="$(find_clone "$slug")"; then
    clone="${found%%"$TAB"*}"; remote="${found#*"$TAB"}"
    if ! git -C "$clone" fetch -q "$remote" "$branch" 2>"$ERRF"; then
      note_err "git fetch $remote $branch in $clone: $(gh_err)"
      echo "  $slug: FAILED (cannot fetch $branch in $clone)"
      return 0
    fi
    if ! git -C "$clone" worktree add -q --detach "$dir/tree" FETCH_HEAD 2>"$ERRF"; then
      note_err "git worktree add in $clone: $(gh_err)"
      echo "  $slug: FAILED (cannot create a worktree of $clone)"
      return 0
    fi
    printf '%s\n' "$clone" >"$dir/source"
    how="worktree of $clone"
  else
    if ! gh repo clone "$slug" "$dir/tree" -- -q --depth 1 --branch "$branch" >/dev/null 2>"$ERRF"; then
      note_err "gh repo clone $slug: $(gh_err)"
      echo "  $slug: FAILED (no local clone, and cloning failed)"
      return 0
    fi
    how="fresh shallow clone"
  fi
  sha="$(git -C "$dir/tree" rev-parse --short HEAD)"

  resolve_context "$dir/tree" "$dir/touched.txt" >"$dir/context.tsv"
  nread="$(grep -c '^read' "$dir/context.tsv" || true)"
  nskip="$(grep -c '^skip' "$dir/context.tsv" || true)"
  {
    echo "# AI context for $slug ($branch @ $sha)"
    echo
    echo "Code: $dir/tree ($how). Files the PRs touched: $(wc -l <"$dir/touched.txt" | tr -d ' ') (touched.txt)."
    echo
    echo "Read these before judging this repo's code. Paths are relative to the tree; where two disagree, the one nearest the code wins."
    echo
    awk -F "$TAB" '$1 == "read" { printf "- %s — %s\n", $2, $3 }' "$dir/context.tsv"
    [ "$nread" != 0 ] || echo "- (none: this repo has no CLAUDE.md, AGENTS.md or rules)"
    if [ "$nskip" != 0 ]; then
      echo
      echo "Not applicable to these changes:"
      echo
      awk -F "$TAB" '$1 == "skip" { printf "- %s — %s\n", $2, $3 }' "$dir/context.tsv"
    fi
  } >"$dir/context.md"

  echo "  $slug  $branch @ $sha  ($how)"
  echo "      code:    $dir/tree"
  echo "      context: $dir/context.md ($nread to read, $nskip not applicable)"
}

{
  echo
  echo "Repos (code at the default branch; read each one's context before its code):"
  if [ -s "$TMP/repos" ]; then
    for slug in $(LC_ALL=C sort -u "$TMP/repos"); do setup_repo "$slug"; done
  else
    echo "  none (no PR found)"
  fi
  if [ -s "$TMP/errors" ]; then
    echo
    echo "Failed (gather these by hand):"
    sed 's/^/  /' "$TMP/errors"
  fi
  echo
  echo "Remove the code trees when done: $0 --cleanup $OUT"
} >>"$OUT/index.md"

cat "$OUT/index.md"
