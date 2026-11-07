#!/usr/bin/env bash
# Fetch everything a PR review starts from into a scratch dir, and print a short
# summary (counts and paths, never content). Read the files you need.
#
# Usage: fetch-pr.sh <PR URL | owner/repo#N | N> [scratch-dir]
#   scratch dir default: ${REVIEW_POWERS_SCRATCH:-${TMPDIR:-/tmp}/review-powers}/review-pr/<repo>-<n>
#
# Writes: meta.json, description.md, ci.json, feeds.md + inline.json +
#   conversation.json + reviews.json, diff.patch (generated files left out),
#   generated.patch (what was left out), omitted.txt (path, size, why).
# Needs: gh, jq.

set -euo pipefail
SKILL_NAME=review-pr
# shellcheck source=lib/feeds.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib/feeds.sh"

need_tools
resolve_pr "${1:-}"
scratch_dir "${2:-}"
REPO_SLUG="$OWNER/$REPO"

# --- metadata ---------------------------------------------------------------
gh pr view "$NUMBER" -R "$REPO_SLUG" --json number,title,body,author,state,isDraft,baseRefName,headRefName,headRefOid,additions,deletions,changedFiles,reviewDecision,url \
  >"$TMP/pr.json" 2>"$ERRF" || die "cannot read PR $REPO_SLUG#$NUMBER: $(gh_err)"
DEFAULT_BRANCH="$(gh repo view "$REPO_SLUG" --json defaultBranchRef --jq .defaultBranchRef.name 2>"$ERRF")" ||
  die "cannot read the default branch of $REPO_SLUG: $(gh_err)"

BASE="$(jq -r .baseRefName "$TMP/pr.json")"
HEAD_SHA="$(jq -r .headRefOid "$TMP/pr.json")"
if [ "$BASE" = "$DEFAULT_BRANCH" ]; then STACKED=false; else STACKED=true; fi

# Ticket keys like ABC-123 in title, body and branch. The branch is upper-cased
# because branch names are usually lowercase (feat/abc-123-x). The denylist drops
# look-alikes that are not tickets (UTF-8, SHA-256, ISO-8601...).
jq --arg default "$DEFAULT_BRANCH" --argjson stacked "$STACKED" '
  def noise: ["UTF","SHA","ISO","RFC","MD","AES","TLS","SSL","HTTP","HTTPS","CVE","WCAG","ES","PR","TS"];
  def keys: [scan("\\b[A-Z][A-Z0-9]+-[0-9]+\\b")] | map(select((split("-")[0]) as $p | noise | index($p) | not));
  (([.title, .body] | map(. // "") | map(keys) | add) + (.headRefName | ascii_upcase | keys) | unique) as $tickets
  | del(.body) + {default_branch: $default, stacked: $stacked, ticket_keys: $tickets}' \
  "$TMP/pr.json" >"$OUT/meta.json"
{
  jq -r '"# \(.title)\n"' "$TMP/pr.json"
  jq -r '(.body // "") | gsub("<!--[\\s\\S]*?-->"; "") | gsub("\n{3,}"; "\n\n") | sub("^\\s+"; "")' "$TMP/pr.json"
} >"$OUT/description.md"

# --- CI ---------------------------------------------------------------------
# gh exits non-zero while checks are pending or failing, so judge by the output.
CI_NOTE=""
gh pr checks "$NUMBER" -R "$REPO_SLUG" --json name,state,bucket,workflow,link >"$TMP/ci.json" 2>"$ERRF" || true
if ! jq -e 'type == "array"' "$TMP/ci.json" >/dev/null 2>&1; then
  if grep -qi 'no checks reported' "$ERRF"; then echo '[]' >"$TMP/ci.json"
  else CI_NOTE="CI unavailable: $(gh_err)"; echo '[]' >"$TMP/ci.json"; fi
fi
cp "$TMP/ci.json" "$OUT/ci.json"

# --- feeds ------------------------------------------------------------------
feeds_fetch

# --- diff without generated files ---------------------------------------------
# Whole diff first; when GitHub refuses it (too large, often because of one
# generated file) rebuild it per file from the files endpoint.
DIFF_NOTE=""
if gh pr diff "$NUMBER" -R "$REPO_SLUG" >"$TMP/full.patch" 2>"$ERRF"; then :
else
  DIFF_NOTE="gh pr diff failed ($(gh_err)); rebuilt from the files endpoint, files without a patch there are listed in omitted.txt as 'no patch'"
  paged "repos/$REPO_SLUG/pulls/$NUMBER/files" "$TMP/files.json"
  jq -r '.[] | select(.patch != null) | "diff --git a/\(.filename) b/\(.filename)\n--- a/\(.filename)\n+++ b/\(.filename)\n\(.patch)"' \
    "$TMP/files.json" >"$TMP/full.patch"
  jq -r '.[] | select(.patch == null) | .filename' "$TMP/files.json" >"$TMP/nopatch.txt"
fi

# Paths the repo marks linguist-generated, from the PR head's root
# .gitattributes (nested ones are ignored). Patterns with a slash match the
# whole path, others the file name anywhere; `*` is allowed to cross `/`, which
# can only over-match inside the named directory.
: >"$TMP/attrs.txt"
if gh api -H 'Accept: application/vnd.github.raw' "repos/$REPO_SLUG/contents/.gitattributes?ref=$HEAD_SHA" \
     >"$TMP/gitattributes" 2>"$ERRF"; then
  awk '/^[[:space:]]*#/ || NF < 2 { next }
       { gen = 0
         for (i = 2; i <= NF; i++) {
           if ($i == "linguist-generated" || $i == "linguist-generated=true") gen = 1
           else if ($i == "-linguist-generated" || $i == "linguist-generated=false") gen = 0
         }
         if (gen) print $1 }' "$TMP/gitattributes" >"$TMP/attrs.txt"
elif ! grep -qiE '404|not found' "$ERRF"; then
  DIFF_NOTE="${DIFF_NOTE:+$DIFF_NOTE; }could not read .gitattributes ($(gh_err)); only name patterns were used"
fi

# generated_reason <path>: sets REASON, returns 0 when the file is generated.
generated_reason() {
  local p="$1" base="${1##*/}" pat
  REASON=""
  while IFS= read -r pat; do
    [ -n "$pat" ] || continue
    pat="${pat#/}"
    case "$pat" in
      */) [[ "$p" == "$pat"* || "$p" == *"/$pat"* ]] && { REASON="linguist-generated"; return 0; } ;;
      */*) pat="${pat//\*\*\//*}"; [[ "$p" == $pat ]] && { REASON="linguist-generated"; return 0; } ;;
      *) [[ "$base" == $pat ]] && { REASON="linguist-generated"; return 0; } ;;
    esac
  done <"$TMP/attrs.txt"
  # Common patterns: lockfiles and bundles nobody reads, plus spec and client
  # files tools write. An OpenAPI spec can be hand-written; it is left out of
  # diff.patch only, and generated.patch keeps it for when the contract matters.
  case "$base" in
    package-lock.json|npm-shrinkwrap.json|yarn.lock|pnpm-lock.yaml|bun.lock|bun.lockb|Gemfile.lock|poetry.lock|Pipfile.lock|Cargo.lock|composer.lock|go.sum|packages.lock.json|mix.lock|Podfile.lock|pubspec.lock|flake.lock|gradle.lockfile|*.lock) REASON="lockfile" ;;
    *.min.js|*.min.css|*.map) REASON="minified or source map" ;;
    openapi.json|openapi.yaml|openapi.yml|swagger.json|swagger.yaml|swagger.yml|*.openapi.json|*.openapi.yaml|*.openapi.yml|*-openapi.json|*-openapi.yaml|*-openapi.yml) REASON="OpenAPI spec" ;;
    *.pb.go|*.pb.cc|*.pb.h|*_pb2.py|*_pb2_grpc.py|*_generated.go|*.generated.*|*.g.cs|*.g.dart|*.Designer.cs|*.designer.cs) REASON="generated code" ;;
  esac
  if [ -z "$REASON" ]; then
    case "$p" in
      generated/*|*/generated/*|__generated__/*|*/__generated__/*) REASON="generated directory" ;;
      node_modules/*|*/node_modules/*|vendor/*|*/vendor/*) REASON="vendored" ;;
    esac
  fi
  [ -n "$REASON" ]
}

# Split the diff per file, then route each file to the kept or the left-out diff.
mkdir -p "$TMP/chunks"
awk -v dir="$TMP/chunks" '
  /^diff --git / {
    if (f != "") close(f)
    n++; f = sprintf("%s/%05d.patch", dir, n)
    p = $0; sub(/^diff --git a\/.* b\//, "", p)
    printf "%05d\t%s\n", n, p >> (dir "/index.tsv")
  }
  f != "" { print >> f }
' "$TMP/full.patch"
: >"$OUT/diff.patch"; : >"$OUT/generated.patch"; : >"$OUT/omitted.txt"
N_KEPT=0; N_OMIT=0; B_KEPT=0; B_OMIT=0
if [ -f "$TMP/chunks/index.tsv" ]; then
  while IFS="$(printf '\t')" read -r id path; do
    bytes="$(wc -c <"$TMP/chunks/$id.patch" | tr -d ' ')"
    if generated_reason "$path"; then
      cat "$TMP/chunks/$id.patch" >>"$OUT/generated.patch"
      printf '%s\t%s bytes\t%s\n' "$path" "$bytes" "$REASON" >>"$OUT/omitted.txt"
      N_OMIT=$((N_OMIT + 1)); B_OMIT=$((B_OMIT + bytes))
    else
      cat "$TMP/chunks/$id.patch" >>"$OUT/diff.patch"
      N_KEPT=$((N_KEPT + 1)); B_KEPT=$((B_KEPT + bytes))
    fi
  done <"$TMP/chunks/index.tsv"
fi
if [ -s "$TMP/nopatch.txt" ]; then
  while IFS= read -r path; do
    printf '%s\tno patch\tGitHub gave no patch for it (too large or binary)\n' "$path" >>"$OUT/omitted.txt"
    N_OMIT=$((N_OMIT + 1))
  done <"$TMP/nopatch.txt"
fi

# --- summary ----------------------------------------------------------------
kb() { echo "$(( ($1 + 1023) / 1024 )) KB"; }
echo "PR $REPO_SLUG#$NUMBER ($(jq -r '"\(.state)\(if .isDraft then ", draft" else "" end)"' "$TMP/pr.json")), author $(jq -r .author.login "$TMP/pr.json")"
echo "  $BASE <- $(jq -r .headRefName "$TMP/pr.json") at ${HEAD_SHA:0:7}; $(jq -r '"+\(.additions) -\(.deletions) in \(.changedFiles) files"' "$TMP/pr.json")"
if [ "$STACKED" = true ]; then echo "  stacked: yes, base is $BASE, not the default branch $DEFAULT_BRANCH"
else echo "  stacked: no, base is the default branch $DEFAULT_BRANCH"; fi
echo "  ticket keys: $(jq -r '.ticket_keys | if length == 0 then "none found" else join(", ") end' "$OUT/meta.json")"
echo "  CI: $(jq -r 'length as $n | "\($n) checks: \([.[] | select(.bucket == "pass")] | length) pass, \([.[] | select(.bucket == "fail")] | length) fail, \([.[] | select(.bucket == "pending")] | length) pending, \([.[] | select(.bucket != "pass" and .bucket != "fail" and .bucket != "pending")] | length) other"' "$OUT/ci.json")${CI_NOTE:+ ($CI_NOTE)}"
echo "  feeds:"
feeds_summary
echo "  diff: $N_KEPT files, $(kb "$B_KEPT") in diff.patch; $N_OMIT files left out ($(kb "$B_OMIT")), listed in omitted.txt"
[ -z "$DIFF_NOTE" ] || echo "  note: $DIFF_NOTE"
echo "wrote to $OUT:"
echo "  meta.json description.md ci.json feeds.md inline.json conversation.json reviews.json diff.patch generated.patch omitted.txt"
