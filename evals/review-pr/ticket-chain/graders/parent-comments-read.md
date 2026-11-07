---
type: regex
target: { source: file, path: .git/tracker-calls.log }
# The decision lives in a comment on the parent story, HOT-530.
pattern: '^READ\ttracker .*(comments.*HOT-530|HOT-530.*comments)'
flags: mi
---
