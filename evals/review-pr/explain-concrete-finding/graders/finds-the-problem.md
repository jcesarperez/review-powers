---
type: llm
weight: 3
---

Judge only whether the reply finds the problem; how it is written is graded
elsewhere.

What actually goes wrong in this PR: before, any discount code other than
LAUNCH10 was simply ignored. Now codes are looked up in a new table, and a code
that is not there (an old, mistyped or retired one already saved on quotes)
makes opening the quote fail with a server error instead of showing the price
without discount.

PASS if the reply says that a quote with an unknown discount code now fails
to load (error) instead of just getting no discount. Any words or code names
are fine.

FAIL if this problem is missing or misstated.
