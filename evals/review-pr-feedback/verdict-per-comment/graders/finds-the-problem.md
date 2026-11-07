---
type: llm
weight: 3
---

Judge only whether the reply gets these two right; how it is written is graded
elsewhere.

- The PMS release: if the PMS refuses to release the rooms, the cancel still
  reports success. The quote shows as cancelled, but its rooms stay blocked in
  the PMS and nobody is told.
- The missing `where`: the reviewer thought cancelling one quote would cancel
  all of them. It doesn't, because the condition is on the next line of the
  same query.

PASS if the reply says both: that a refused release still reports success and
leaves rooms blocked, and that the `where` comment is a false alarm because
the condition is there. Any words or code names are fine.

FAIL if either is missing or misstated.
