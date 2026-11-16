---
type: regex
target: { source: file, path: .git/HEAD }
# The scaffold leaves the user on main; a PR checkout must not move them.
pattern: '^ref: refs/heads/main$'
flags: m
---
