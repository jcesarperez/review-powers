---
type: llm
weight: 3
---

You are a reader who has never seen this codebase and can only read the reply.

What actually goes wrong in this PR: before, any discount code other than
LAUNCH10 was simply ignored. Now codes are looked up in a new table, and a code
that is not there (an old, mistyped or retired one already saved on quotes)
makes opening the quote fail with a server error instead of showing the price
without discount.

PASS if, from the reply alone, the reader would understand that a quote with
an unknown discount code now fails to load (error) instead of just getting no
discount.

FAIL if this problem is missing, or is only described in code terms.
