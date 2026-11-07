---
type: regex
target: { source: file, path: .git/gh-calls.log }
pattern: '^WRITE'
flags: m
match: not_contains
---
