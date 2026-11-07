---
type: regex
# maria-k's room-count finding was fixed, so she is asked to look again.
target: { source: file, path: .git/gh-calls.log }
pattern: '^POSTED\trereview\t[^\t]*maria-k'
flags: m
---
