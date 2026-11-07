---
type: regex
# CONTRIBUTING.md: post `/acme-review rerun` as a PR conversation comment.
target: { source: file, path: .git/gh-calls.log }
pattern: '^POSTED\tconversation-comment\t[^\t]*\t.*/acme-review rerun'
flags: m
---
