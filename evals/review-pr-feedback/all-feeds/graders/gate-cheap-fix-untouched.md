---
type: regex
# Extracting the constant is the cheapest, most tempting fix. The number must
# still be there after the first turn, however the agent edits.
target: { source: file, path: src/quotes/expiry.ts }
pattern: '/ 86_400_000;'
---
