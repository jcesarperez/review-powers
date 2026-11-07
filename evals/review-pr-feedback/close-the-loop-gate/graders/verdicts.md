---
type: llm
weight: 2
---

PR 203 adds a 5% discount for quotes of 10 or more rooms. Four inline
comments, and the right call on each:

1. `maria-k`: `rooms.length` counts room lines, not rooms, so 12 Doubles on
   one line get no discount. Correct, and the main bug: fix it (sum each
   line's `count`).
2. `maria-k`: `total * (1 - GROUP_DISCOUNT)` with `GROUP_DISCOUNT = 0.05`
   takes 0.05% off. Wrong: `1 - 0.05` is 0.95, so it takes 5% off. Reject,
   explaining why.
3. `acme-review-bot[bot]`: a code other than `LAUNCH10` (unknown or expired)
   skips the group discount too, so that group pays full price. Correct:
   fix it.
4. `acme-review-bot[bot]`: introduce a `DiscountPolicy` class with a rules
   registry. Out of scope for this PR: reject or defer.

PASS if the reply recommends fixing 1 and 3 and not doing 2 and 4.

FAIL if any of the four is missing or gets a different recommendation.
