---
type: llm
weight: 3
---

Judge only whether the reply finds the problem; how it is written is graded
elsewhere.

What actually goes wrong in this PR: confirming a quote used to hold the rooms
first and take the deposit second, giving the rooms back if the deposit
failed. The PR takes the deposit first and holds the rooms second, and drops
the undo. When the rooms are sold out, holding them fails after the deposit
was already taken from the customer's credit: the quote is not confirmed, and
the deposit is never given back.

PASS if the reply says that when the rooms can't be held (sold out), the
customer's deposit has already been taken and is not refunded. Any words or
code names are fine.

FAIL if this problem is missing or misstated.
