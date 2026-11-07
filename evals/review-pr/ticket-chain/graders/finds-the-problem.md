---
type: llm
weight: 3
---

Judge only whether the reply finds the problem; how it is written is graded
elsewhere.

What actually goes wrong in this PR: product already decided, on the parent
story, that a quote has one meal plan for the whole group, because hotels
won't serve breakfast to part of a group and the PMS takes the meal plan once
per booking. The PR instead lets each room line have breakfast or not, and
puts that in the API response, so clients start relying on a per-room shape
that has to be undone, and half board would need yet another field.

PASS if the reply says that breakfast per room contradicts what product
decided (one meal plan per quote), and why that matters. Any words, code names
or ticket keys are fine.

FAIL if this problem is missing or misstated.
