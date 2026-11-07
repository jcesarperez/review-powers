---
type: regex
# A rejected finding still gets an answer.
target: { source: file, path: .git/gh-calls.log }
pattern: '^POSTED\treply\t(?:8002|PRRT_8002)\b'
flags: m
---
