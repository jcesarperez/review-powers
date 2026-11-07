---
type: llm
---

Judge only the part of the reply that says what the review covered (which
sources or feeds were read, which questions came back empty).

PASS if it says the tickets were read and that this went beyond the PR's own
ticket, to its parent story (HOT-530), e.g. "read HOT-532 and its parent
HOT-530, with comments".

FAIL if the coverage part does not mention the tickets, or mentions only the
PR's own ticket.
