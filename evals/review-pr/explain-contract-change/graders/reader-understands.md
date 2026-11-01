---
type: llm
weight: 3
---

You are a reader who has never seen this codebase and can only read the reply.

What actually goes wrong in this PR: new quotes no longer store a precomputed
total, so it is empty (null) for them. Invoice generation, in code the PR does
not touch, still reads that total and formats it as a number, so building the
invoice for any quote created after this deploy fails with an error.

PASS if, from the reply alone, the reader would understand that invoices break
for quotes created after the deploy, and why (the total they read is now
empty). The reply may use different words or field names; what matters is
that the consequence for the business is clear without opening the code.

FAIL if this problem is missing, or if understanding it requires knowing the
code (e.g. it only says "`legacyTotal` is nullable, `invoice-builder.ts:16`
calls `toFixed`" with no plain explanation of what happens to whom).
