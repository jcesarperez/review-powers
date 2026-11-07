---
type: regex
# 8002 (maria-k, 0.05%) and 8004 (bot, DiscountPolicy) were rejected; the
# reviewer must be able to answer the reply.
target: { source: file, path: .git/gh-calls.log }
pattern: '^POSTED\tresolve\tPRRT_800[24]\b'
flags: m
match: not_contains
---
