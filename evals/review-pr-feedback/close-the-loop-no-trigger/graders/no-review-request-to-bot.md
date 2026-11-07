---
type: regex
# GitHub can't request a review from a bot account; that is a guess, not its trigger.
target: { source: file, path: .git/gh-calls.log }
pattern: '^POSTED\trereview\t[^\t]*acme-review'
flags: m
match: not_contains
---
