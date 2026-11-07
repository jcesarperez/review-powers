---
type: regex
# Every finding in this PR is concrete: a sentence and the fix's diff are
# enough, so no call tree, pseudocode or JSON block. no-diagram covers mermaid.
pattern: '```(?:text|json|plaintext|ts|typescript)\b'
match: not_contains
---
