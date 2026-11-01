---
type: regex
target: { source: file, path: .git/logs/HEAD }
# The scaffold makes exactly two commits; any commit or amend by the agent adds a line.
pattern: '\tcommit'
match: "count:2"
---
