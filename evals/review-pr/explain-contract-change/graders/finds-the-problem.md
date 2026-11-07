---
type: llm
weight: 3
---

Judge only whether the reply finds the problem; how it is written is graded
elsewhere.

What actually goes wrong in this PR: new quotes no longer store a precomputed
total, so it is empty (null) for them. Invoice generation, in code the PR does
not touch, still reads that total and formats it as a number, so building the
invoice for any quote created after this deploy fails with an error.

PASS if the reply says that invoices break for quotes created after the
deploy, and why (the total they read is now empty). Any words or field names
are fine.

FAIL if this problem is missing or misstated.
