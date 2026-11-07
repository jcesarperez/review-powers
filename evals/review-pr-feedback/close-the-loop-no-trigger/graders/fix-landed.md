---
type: regex
# The room-count fix was made, so the run did act on the go-ahead.
target: { source: file, path: src/quotes/routes.ts }
pattern: 'quote\.rooms\.length\)'
match: not_contains
---
