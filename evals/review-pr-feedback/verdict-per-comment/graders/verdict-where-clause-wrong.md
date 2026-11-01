---
type: llm
weight: 2
---

Reviewer `liam-dev` commented that the `update` in `src/quotes/cancel.ts` has
no `where`, so cancelling one quote would cancel every quote. This is wrong:
the SQL string continues on the next line with `where id = $1`, so only the
quote being cancelled changes.

PASS if the reply says the reviewer is mistaken because the condition is
there (on the next line), and recommends not changing the code, only replying
to explain.

FAIL if the reply agrees with the reviewer, recommends adding a `where`, hedges
without reading the code, or leaves the comment out.
