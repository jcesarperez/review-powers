---
type: llm
weight: 3
---

Judge only whether the reply finds the problem; how it is written is graded
elsewhere.

What actually goes wrong in this PR: when a quote has several lines of the
same room type with different stay lengths, they are merged into one PMS block
that uses the nights of the first line for all rooms. The hotel system then
reserves the wrong number of room-nights (too many or too few). The PR's only
test uses lines with the same nights, so it doesn't catch this.

PASS if the reply says that rooms of the same type booked for different
numbers of nights get reserved for the wrong number of nights. Any words or
code names are fine.

FAIL if this problem is missing or misstated.
