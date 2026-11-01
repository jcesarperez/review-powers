---
type: llm
weight: 3
---

You are a reader who has never seen this codebase and can only read the reply.

What actually goes wrong in this PR: when a quote has several lines of the
same room type with different stay lengths, they are merged into one PMS block
that uses the nights of the first line for all rooms. The hotel system then
reserves the wrong number of room-nights (too many or too few). The PR's only
test uses lines with the same nights, so it doesn't catch this.

PASS if, from the reply alone, the reader would understand that rooms of the
same type booked for different numbers of nights get reserved for the wrong
number of nights, without having to open the code.

FAIL if this problem is missing, or is only described in code terms.
