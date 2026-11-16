---
type: regex
target: { source: file, path: .git/tracker-calls.log }
# Without acli the ticket comes from the tool the repo documents, the tracker.
pattern: '^READ\ttracker .*HOT-530'
flags: m
---
