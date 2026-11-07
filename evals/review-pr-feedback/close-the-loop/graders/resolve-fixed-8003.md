---
type: regex
# The pushed fix settles this thread, so it is resolved.
target: { source: file, path: .git/gh-calls.log }
pattern: '^POSTED\tresolve\tPRRT_8003\b'
flags: m
---
