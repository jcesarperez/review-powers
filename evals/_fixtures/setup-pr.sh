#!/usr/bin/env bash
# Builds the hotel-api repo with one fixture PR and wires the fake `gh` to it.
# Called from a case's scaffold script, whose cwd is the empty eval workspace.
# Usage: setup-pr.sh <pr-number>
#   ./                       git repo on main = base/; the PR branch (base/ + prs/<n>/files/) is on origin only
#   ./.git/gh-calls.log      every gh call, READ or WRITE (graders read it)
#   $HOME/origin/            bare clone acting as the GitHub remote
#   $HOME/.gh-fixture/       data the fake gh serves, outside the agent's repo
#   $HOME/.bin/gh            the fake gh, put first on PATH by the shell profiles

set -euo pipefail
N="$1"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PR_DIR="$HERE/hotel-api/prs/$N"
REPO="$(pwd)"
DATA="$HOME/.gh-fixture"

cp -R "$HERE/hotel-api/base/." "$REPO/"
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
git checkout -q main

# A local bare "origin" that also has GitHub's refs/pull/<n>/head, so fetching
# the PR works without network.
ORIGIN="$HOME/origin/hotel-api.git"
git clone -q --bare "$REPO" "$ORIGIN"
git -C "$ORIGIN" update-ref "refs/pull/$N/head" "refs/heads/$HEAD_BRANCH"
git remote add origin "$ORIGIN"
git fetch -q origin
git branch -q --set-upstream-to=origin/main main
# A reviewer has the PR only on the remote until they check it out.
git branch -q -D "$HEAD_BRANCH"

mkdir -p "$DATA" "$HOME/.bin"
cp "$PR_DIR"/*.json "$DATA/"
# Precomputed so the fake gh doesn't need git inside the sandbox.
git diff "main...origin/$HEAD_BRANCH" > "$DATA/diff.patch"
git diff --name-status "main...origin/$HEAD_BRANCH" > "$DATA/name-status.txt"
printf '%s' "$REPO" > "$DATA/repo"
: > "$REPO/.git/gh-calls.log"
cp "$HERE/bin/gh" "$HOME/.bin/gh"
chmod +x "$HOME/.bin/gh"

# The agent's shell loads these, so this is how the fake gh reaches its PATH.
# On macOS /usr/bin/git is an xcrun shim that fails inside the sandbox, so a
# copy of the real binary goes next to the fake gh.
if command -v xcode-select >/dev/null && [ -x "$(xcode-select -p)/usr/bin/git" ]; then
  cp "$(xcode-select -p)/usr/bin/git" "$HOME/.bin/git"
  # Fetching from the local origin execs this helper; it's a git builtin.
  ln -s git "$HOME/.bin/git-upload-pack"
fi
for f in .zshenv .zshrc .bashrc .bash_profile .profile; do
  printf 'export PATH="%s:$PATH"\nexport GH_FIXTURE_DIR="%s"\n' "$HOME/.bin" "$DATA" >> "$HOME/$f"
done
