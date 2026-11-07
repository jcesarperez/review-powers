---
type: llm
weight: 3
---

Judge only whether the reply gets these two right; how it is written is graded
elsewhere.

- `>` vs `>=`: the age is measured in milliseconds, so both versions expire a
  quote at the same moment, exactly 14 × 24 hours after it was created. They
  differ only for that single millisecond, so the change would not do what
  the reviewer expects.
- Invoicing: invoices are built from the quote without going through the
  endpoint that now refuses expired quotes, so old stays are still invoiced.

PASS if the reply says, for each, what it concludes and why. It may reach a
different conclusion on `>=` (e.g. that the intent should be "whole calendar
days") as long as it gives the millisecond reasoning. Any words or code names
are fine.

FAIL if either is missing or misstated.
