#!/usr/bin/env bash
# Builds the hotel-api repo with one fixture PR and wires the fake `gh` to it.
# Called from a case's scaffold script, whose cwd is the empty eval workspace.
# Usage: setup-pr.sh <pr-number> [reviewer|author]
#   reviewer (default)       ./ is a git repo on main = base/; the PR branch (base/ + prs/<n>/files/) is on origin only
#   author                   ./ is on the PR branch, tracking origin; gh is logged in as the PR's author
#   ./.git/gh-calls.log      every gh call, READ or WRITE, and a POSTED line per write (graders read it)
#   prs/<n>/main/            optional files on main the PR doesn't touch; NO_MAIN_FILES=1 skips them
#   $HOME/origin/            bare clone acting as the GitHub remote
#   $HOME/.gh-fixture/       data the fake gh serves, outside the agent's repo
#   $HOME/.bin/gh            the fake gh, put first on PATH by the shell profiles
#   $HOME/.bin/tracker       the fake issue tracker, serving prs/<n>/tickets/*.json
#   ./.git/tracker-calls.log every tracker call (graders read it)

set -euo pipefail
N="$1"
ROLE="${2:-reviewer}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PR_DIR="$HERE/hotel-api/prs/$N"
REPO="$(pwd)"
DATA="$HOME/.gh-fixture"
mkdir -p "$DATA" "$HOME/.bin"

cp -R "$HERE/hotel-api/base/." "$REPO/"
# Files on main that the PR doesn't touch, such as a contributing guide.
# NO_MAIN_FILES=1 leaves them out, for a variant of the same PR without them.
if [ -d "$PR_DIR/main" ] && [ "${NO_MAIN_FILES:-}" != 1 ]; then
  cp -R "$PR_DIR/main/." "$REPO/"
fi
# Fixed dates make the commit ids the same on every scaffold, so a recorded
# first turn (a case's history_file) cites the commits the replay has.
export GIT_AUTHOR_DATE="2026-11-03T10:00:00Z" GIT_COMMITTER_DATE="2026-11-03T10:00:00Z"
git init -q -b main
git config user.email dev@acme.test
git config user.name "Acme Dev"
git add -A
git commit -q -m "Initial hotel-api"

HEAD_BRANCH="$(jq -r .headRefName "$PR_DIR/pr.json")"
git checkout -q -b "$HEAD_BRANCH"
cp -R "$PR_DIR/files/." "$REPO/"
git add -A
git commit -q -m "$(jq -r .title "$PR_DIR/pr.json")"
[ "$ROLE" = author ] || git checkout -q main

# A local bare "origin" that also has GitHub's refs/pull/<n>/head, so fetching
# the PR works without network.
ORIGIN="$HOME/origin/hotel-api.git"
git clone -q --bare "$REPO" "$ORIGIN"
git -C "$ORIGIN" update-ref "refs/pull/$N/head" "refs/heads/$HEAD_BRANCH"
git remote add origin "$ORIGIN"
git fetch -q origin
git branch -q --set-upstream-to=origin/main main
if [ "$ROLE" = author ]; then
  git branch -q --set-upstream-to="origin/$HEAD_BRANCH" "$HEAD_BRANCH"
  jq -r .author.login "$PR_DIR/pr.json" > "$DATA/viewer"
else
  echo reviewer > "$DATA/viewer"
  # A reviewer has the PR only on the remote until they check it out.
  git branch -q -D "$HEAD_BRANCH"
fi

cp "$PR_DIR"/*.json "$DATA/"
# Precomputed so the fake gh doesn't need git inside the sandbox.
git diff "main...origin/$HEAD_BRANCH" > "$DATA/diff.patch"
git diff --name-status "main...origin/$HEAD_BRANCH" > "$DATA/name-status.txt"
# What `gh pr view --json` adds on a real PR: head commit and size.
git diff --numstat "main...origin/$HEAD_BRANCH" | awk '{a += $1; d += $2; n++} END {printf "{\"additions\": %d, \"deletions\": %d, \"changedFiles\": %d}", a, d, n}' > "$DATA/size.json"
jq --arg sha "$(git rev-parse "origin/$HEAD_BRANCH")" --slurpfile size "$DATA/size.json" \
  '. + {headRefOid: $sha} + $size[0]' "$PR_DIR/pr.json" > "$DATA/pr.json"
# Served as the PR head's root .gitattributes, when the PR has one.
[ -f "$PR_DIR/files/.gitattributes" ] && cp "$PR_DIR/files/.gitattributes" "$DATA/gitattributes"
printf '%s' "$REPO" > "$DATA/repo"
# The fake gh reads the PR head from here, so a push moves it as on GitHub.
printf '%s' "$ORIGIN" > "$DATA/origin"
: > "$REPO/.git/gh-calls.log"
cp "$HERE/bin/gh" "$HOME/.bin/gh"
chmod +x "$HOME/.bin/gh"
# The issue tracker the repo's README points to. Every PR gets it; one without
# tickets answers "not found", like a real tracker for a key nobody filed.
mkdir -p "$DATA/tickets"
[ -d "$PR_DIR/tickets" ] && cp "$PR_DIR"/tickets/*.json "$DATA/tickets/"
: > "$REPO/.git/tracker-calls.log"
cp "$HERE/bin/tracker" "$HOME/.bin/tracker"
chmod +x "$HOME/.bin/tracker"

# The agent's shell loads these, so this is how the fake gh reaches its PATH.
# On macOS /usr/bin/git is an xcrun shim that fails inside the sandbox, so a
# copy of the real binary goes next to the fake gh.
if command -v xcode-select >/dev/null && [ -x "$(xcode-select -p)/usr/bin/git" ]; then
  cp "$(xcode-select -p)/usr/bin/git" "$HOME/.bin/git"
  # Fetching from the local origin execs this helper; it's a git builtin.
  ln -s git "$HOME/.bin/git-upload-pack"
  # Pushing to it execs this one.
  ln -s git "$HOME/.bin/git-receive-pack"
fi
for f in .zshenv .zshrc .bashrc .bash_profile .profile; do
  printf 'export PATH="%s:$PATH"\nexport GH_FIXTURE_DIR="%s"\n' "$HOME/.bin" "$DATA" >> "$HOME/$f"
done
