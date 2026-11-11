#!/usr/bin/env bash
# Publish a release: fast-forward main to develop, tag it, create the GitHub Release.
# Usage: scripts/release.sh X.Y.Z [--dry-run] [--yes]
# Works from any branch or checkout state: it reads develop, never checks anything out.
# Bash 3.2, git, gh, jq.
set -euo pipefail

ver="${1:-}"; shift || true
dry=0; yes=0
for a in "$@"; do
  case "$a" in
    --dry-run) dry=1 ;;
    --yes) yes=1 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done
[[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "usage: $0 X.Y.Z [--dry-run] [--yes]" >&2; exit 2; }
tag="v$ver"

cd "$(git rev-parse --show-toplevel)"
export GH_TOKEN="${GH_TOKEN:-$(gh auth token -u jcesarperez)}"
fail() { echo "release: $*" >&2; exit 1; }

echo "== fetch"
git fetch -q origin develop main --tags --force
sha=$(git rev-parse origin/develop)
[ "$(git rev-parse develop)" = "$sha" ] || fail "local develop differs from origin/develop; push or pull first"
git merge-base --is-ancestor origin/main "$sha" || fail "origin/main is not an ancestor of develop; main would not fast-forward"
[ "$(git rev-parse origin/main)" != "$sha" ] || fail "main already equals develop; nothing to release"
git rev-parse -q --verify "refs/tags/$tag" >/dev/null && fail "tag $tag already exists"

echo "== version and changelog at develop"
[ "$(git show "$sha:.claude-plugin/plugin.json" | jq -r .version)" = "$ver" ] \
  || fail "plugin.json on develop is not version $ver"
git show "$sha:CHANGELOG.md" | grep -q "^## \[$ver\] - " || fail "CHANGELOG.md has no '## [$ver] - <date>' entry"
if git show "$sha:CHANGELOG.md" | awk '/^## \[Unreleased\]/{f=1;next} /^## \[/{f=0} f&&NF' | grep -q .; then
  fail "CHANGELOG.md still has Unreleased entries"
fi

echo "== CI on develop's commit"
conclusion=$(gh run list --workflow ci.yml --commit "$sha" --json conclusion,status --jq '[.[]|select(.status=="completed")][0].conclusion // "none"')
[ "$conclusion" = "success" ] || fail "CI on $sha is '$conclusion', not success"

echo "== tests on a clean export of develop"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
git archive "$sha" | tar -x -C "$tmp"
for s in review-pr-feedback review-ticket; do
  cmp "$tmp/skills/review-pr/scripts/lib/feeds.sh" "$tmp/skills/$s/scripts/lib/feeds.sh"
done
(cd "$tmp" && tests/review-ticket/run.sh >/dev/null) || fail "review-ticket tests fail"

echo "== will release $tag"
git log --oneline "origin/main..$sha"
if [ "$dry" = 1 ]; then echo "(dry run: nothing pushed)"; exit 0; fi
if [ "$yes" != 1 ]; then
  read -r -p "Fast-forward main to $sha and publish $tag? [y/N] " ans
  [ "$ans" = y ] || fail "aborted"
fi

notes="$tmp/notes.md"
awk -v v="$ver" '$0 ~ "^## \\[" v "\\]"{f=1;next} /^## \[/{f=0} f' "$tmp/CHANGELOG.md" > "$notes"

git tag -a "$tag" "$sha" -m "$tag"
git push --atomic origin "$sha:refs/heads/main" "refs/tags/$tag"
gh release create "$tag" --verify-tag --title "$tag" --notes-file "$notes"
echo "released $tag"
