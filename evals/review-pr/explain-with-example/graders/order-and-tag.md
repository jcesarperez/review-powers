---
type: llm
weight: 1
---

Judge only the order of the findings and their tags; whether the problem is
found is graded elsewhere.

The finding that costs most if ignored is the one where rooms of the same type
with different stay lengths are reserved for the wrong number of nights.

PASS if that finding is listed first, and every finding starts with a short
tag naming what it is about (e.g. Bug, Tests, Design).

FAIL if another finding comes before it, or any finding has no tag. If the
reply misses that problem entirely, FAIL.
