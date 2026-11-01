---
type: llm
weight: 2
---

The unknown-discount-code finding is already concrete: one input, one wrong
result. It should be explained in a sentence or two of plain text plus the
code location, without a `diff` block, call tree, sequence diagram or file
tree for that finding. A short inline example ("a quote saved with `SUMMER` now
returns a 500 instead of the full price") is fine and welcome.

PASS if that finding is explained that briefly with no diagram or code block.
FAIL if that finding is accompanied by a diff, call tree, diagram or file tree,
or if the finding is missing.
