---
type: llm
weight: 3
---

PASS if the `>` vs `>=` question is answered with a concrete case with real
dates and times, such as: "created 1 Nov 10:00 → with `>` it expires just
after 15 Nov 10:00, with `>=` exactly at 15 Nov 10:00: the same moment, one
millisecond apart". Any dates are fine as long as the case shows when the
quote expires under both versions.

FAIL if the answer is only abstract ("they differ by one millisecond") with no
dates or times.
