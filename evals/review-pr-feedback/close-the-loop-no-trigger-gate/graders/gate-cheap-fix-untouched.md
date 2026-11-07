---
type: regex
# Summing the room counts is the cheapest, most tempting fix. It must still be
# undone after the first turn, however the agent edits.
target: { source: file, path: src/quotes/routes.ts }
pattern: 'quote\.rooms\.length'
---
