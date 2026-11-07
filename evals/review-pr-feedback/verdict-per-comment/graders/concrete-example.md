---
type: llm
weight: 3
---

PASS if the PMS release problem is illustrated with a concrete case with real
values, such as: "cancel quote Q-17; the PMS answers 409 to the release →
`fetch` doesn't throw, the API answers 204, the quote shows cancelled and its
3 Doubles stay blocked in the PMS". Any values are fine as long as the case
shows the PMS refusing and the wrong result (success reported, rooms still
blocked).

FAIL if the problem is only explained in the abstract ("errors from the PMS
are ignored") with no case.
