#!/usr/bin/env bash
# Deterministic tests for review-ticket's scripts (gather.py, md2adf.sh): fake
# gh and acli, local git repos standing in for GitHub, golden outputs. No
# network, no model.
#
# Usage: tests/review-ticket/run.sh            run; diffs on failure
#        tests/review-ticket/run.sh --update   rewrite expected/ from this run
#                                              (review the diff before committing)

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Physical path: gather.py prints its own path resolved, and /var is a symlink on macOS.
ROOT="$(cd "$HERE/../.." && pwd -P)"
S="$ROOT/skills/review-ticket/scripts"
UPDATE="${1:-}"

T="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/review-ticket-test.XXXXXX")" && pwd -P)"
trap 'rm -rf "$T"' EXIT

export PATH="$HERE/bin:$PATH"
export FAKE_GH_FIXTURES="$HERE/fixtures" FAKE_GH_REMOTES="$T/remotes" FAKE_GH_LOG="$T/gh.log"
export REVIEW_TICKET_NO_WAIT=1
# Fixed identities and dates make commit SHAs stable; the user's git config
# (insteadOf rules, hooks, signing) stays out.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export GIT_AUTHOR_DATE=2026-01-01T00:00:00Z GIT_COMMITTER_DATE=2026-01-01T00:00:00Z

PASS=0 FAIL=0
ok() { PASS=$((PASS + 1)); echo "ok   $1"; }
ko() { FAIL=$((FAIL + 1)); echo "FAIL $1"; [ -z "${2:-}" ] || printf '%s\n' "$2" | sed 's/^/     /'; }

# Paths and SHAs vary per run; goldens hold placeholders.
norm() { sed -e "s#$T#<tmp>#g" -e "s#$S#<scripts>#g" -e 's/@ [0-9a-f]\{7,\}/@ <sha>/g' "$@"; }

# golden <name> <actual file>: compare with expected/<name>, normalized.
golden() {
  local exp="$HERE/expected/$1"
  norm "$2" >"$T/actual"
  if [ "$UPDATE" = --update ]; then cp "$T/actual" "$exp"; ok "$1 (updated)"; return; fi
  if [ -f "$exp" ] && diff -u "$exp" "$T/actual" >"$T/diff"; then ok "$1"
  else ko "$1" "$(cat "$T/diff" 2>/dev/null || echo "missing $exp; run with --update")"; fi
}

# assert <name> <command...>
assert() {
  local name="$1"; shift
  if "$@" >"$T/assert.out" 2>&1; then ok "$name"; else ko "$name" "$(cat "$T/assert.out")"; fi
}

# --- repos standing in for GitHub ---------------------------------------------
# remotes/<name>.git is "GitHub". workspace/hotel-api is the user's clone: its
# origin reads git@github.com:acme/hotel-api.git, rewritten to the local remote,
# and it sits on a branch of its own with an uncommitted file, which gather
# must leave alone. acme/web has no clone, so gather clones it.
mkdir -p "$T/remotes" "$T/workspace"
for name in hotel-api web; do
  git init -q -b main "$T/src-$name"
  cp -R "$HERE/fixtures/repos/$name/." "$T/src-$name/"
  git -C "$T/src-$name" add -A
  git -C "$T/src-$name" commit -q -m "initial"
  git clone -q --bare "$T/src-$name" "$T/remotes/$name.git"
done
CLONE="$T/workspace/hotel-api"
git clone -q "$T/remotes/hotel-api.git" "$CLONE"
git -C "$CLONE" config url."$T/remotes/hotel-api.git".insteadOf git@github.com:acme/hotel-api.git
git -C "$CLONE" remote set-url origin git@github.com:acme/hotel-api.git
git -C "$CLONE" checkout -q -b my-work
echo "work in progress" >"$CLONE/wip.txt"

# --- AI context resolution, directly ------------------------------------------
printf '%s\n' src/rates/rate.ts src/rates/price.ts src/util/x.ts src/util/gen.ts src/generated/client.ts >"$T/touched.txt"
"$S/gather.py" context "$CLONE" "$T/touched.txt" >"$T/context.tsv"
golden context-hotel-api.tsv "$T/context.tsv"

printf '%s\n' web/index.ts >"$T/touched-web.txt"
"$S/gather.py" context "$CLONE" "$T/touched-web.txt" >"$T/context-web.tsv"
golden context-other-files.tsv "$T/context-web.tsv"

# Rule globs as Claude Code documents them: (pattern, path, 1 match | 0 no match).
cat >"$T/globs.py" <<'PY'
import sys; sys.path.insert(0, sys.argv[1]); import gather
cases = [("*.md", "README.md", 1), ("*.md", "docs/sub/x.md", 1), ("/*.md", "README.md", 1), ("/*.md", "docs/x.md", 0),
         ("src/components/*.tsx", "src/components/A.tsx", 1), ("src/components/*.tsx", "src/components/x/A.tsx", 0),
         ("**/*.ts", "a.ts", 1), ("**/*.ts", "a/b/c.ts", 1), ("src/", "src/a/b", 1), ("src/**/*.{ts,tsx}", "src/a.tsx", 1),
         ("file[0-9].ts", "file3.ts", 1), ("file[!0-9].ts", "file3.ts", 0), ("photos [2024/**", "photos [2024/a", 0)]
bad = [c for c in cases if gather.glob_match(c[1], c[0]) != bool(c[2])]
sys.exit("wrong: %s" % bad if bad else 0)
PY
assert "rule globs match as documented" python3 -I "$T/globs.py" "$S"

# --- full gather, owner inferred ----------------------------------------------
OUT="$T/out"
(cd "$T" && "$S/gather.py" --repos-dir "$T/workspace" ABC-100 "$OUT") >"$T/index.txt" 2>"$T/stderr" ||
  ko "gather exits 0" "$(cat "$T/stderr")"
golden index.txt "$T/index.txt"
golden jira-ABC-100.md "$OUT/jira/ABC-100.md"
golden jira-ABC-101.md "$OUT/jira/ABC-101.md"
golden pr-hotel-api-1.md "$OUT/prs/hotel-api-1/pr.md"
golden feeds-hotel-api-1.md "$OUT/prs/hotel-api-1/feeds.md"
golden context-hotel-api.md "$OUT/repos/acme-hotel-api/context.md"
golden context-web.md "$OUT/repos/acme-web/context.md"

assert "hotel-api is read from a worktree of the local clone" \
  test "$(git -C "$CLONE" worktree list | grep -c "$OUT/repos/acme-hotel-api/tree")" = 1
assert "the clone keeps its branch and uncommitted work" \
  sh -c "[ \"\$(git -C '$CLONE' branch --show-current)\" = my-work ] && [ -f '$CLONE/wip.txt' ]"
assert "web, with no local clone, is cloned into the out dir" test -f "$OUT/repos/acme-web/tree/src/app.tsx"
assert "PRs are searched without an owner when none is given" \
  sh -c "! grep -q -- '--owner' '$T/gh.log'"

# --- cleanup ----------------------------------------------------------------------
"$S/gather.py" --cleanup "$OUT" >/dev/null
assert "cleanup removes every code tree" sh -c "! ls -d '$OUT'/repos/*/tree 2>/dev/null"
assert "cleanup unregisters the worktree" test "$(git -C "$CLONE" worktree list | wc -l | tr -d ' ')" = 1
assert "cleanup keeps the gathered files" test -f "$OUT/repos/acme-hotel-api/context.md"
assert "cleanup is safe to repeat" "$S/gather.py" --cleanup "$OUT"

# --- owner given, ticket as a URL ---------------------------------------------
: >"$T/gh.log"
(cd "$T" && "$S/gather.py" --owner acme --repos-dir "$T/workspace" \
  "https://jira-1.example.com/browse/abc-100?focusedCommentId=1" "$T/out2") >"$T/index2.txt" 2>"$T/stderr" ||
  ko "gather --owner exits 0" "$(cat "$T/stderr")"
assert "the key comes from the URL path, not the host" grep -q '^Ticket ABC-100:' "$T/index2.txt"
assert "--owner reaches every search" test "$(grep -c '^search prs .* --owner acme' "$T/gh.log")" = 3
assert "--owner leaves other owners' PRs out" sh -c "! grep -q 'other/fork' '$T/index2.txt'"
"$S/gather.py" --cleanup "$T/out2" >/dev/null

# --- a killed run -------------------------------------------------------------
# acme/web hangs and the run is killed meanwhile. index.md must already hold
# everything gathered, with acme/web marked PENDING, not missing.
(cd "$T" && FAKE_GH_HANG=acme/web exec "$S/gather.py" --repos-dir "$T/workspace" ABC-100 "$T/out4") >/dev/null 2>&1 &
pid=$!
for _ in $(seq 1 100); do grep -q 'acme/hotel-api  main @' "$T/out4/index.md" 2>/dev/null && break; sleep 0.1; done
kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null || true
assert "a killed run leaves its index, with the unfinished repo PENDING" \
  sh -c "grep -q 'acme/web: PENDING' '$T/out4/index.md' && grep -q 'acme/hotel-api  main @' '$T/out4/index.md' && grep -q 'still gathering' '$T/out4/index.md'"
assert "a finished run's index has nothing pending" sh -c "! grep -qE 'PENDING|still gathering' '$T/index.txt'"
"$S/gather.py" --cleanup "$T/out4" >/dev/null

# --- failures -------------------------------------------------------------------
assert "no key in the argument is an error" sh -c "! '$S/gather.py' 'no key here' '$T/out3' 2>/dev/null"
assert "an unreadable ticket stops the gather" \
  sh -c "! '$S/gather.py' ABC-999 '$T/out3' 2>'$T/err3' && grep -q 'cannot read the ticket ABC-999' '$T/err3'"

# --- md2adf -----------------------------------------------------------------------
"$S/md2adf.sh" "$HERE/fixtures/task.md" | jq . >"$T/task.json"
golden task.json "$T/task.json"
assert "md2adf output is an ADF doc" jq -e '.type == "doc" and .version == 1' "$T/task.json"
assert "every task node has a unique localId" \
  jq -e '[.. | objects | select(.type == "taskList" or .type == "taskItem") | .attrs.localId] | (length > 0) and (length == (unique | length))' "$T/task.json"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
