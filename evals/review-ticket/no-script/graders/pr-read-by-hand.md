---
type: regex
target: { source: file, path: .git/gh-calls.log }
# The PR is found through HOT-532's comment and read without gather.py.
pattern: '^READ\tgh .*(pr (view|diff) .*105|pulls/105)'
flags: m
---
