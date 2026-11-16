---
type: llm
weight: 3
---

Judge only whether the reply finds the problem; how it is written is graded
elsewhere.

What actually goes wrong: on the story HOT-530, product decided that a quote
has one meal plan for the whole group (`mealPlan`), because hotels won't serve
breakfast to part of a group and the PMS takes the meal plan once per booking.
PR 105, for the subtask HOT-532, adds a breakfast flag per room line instead,
and returns it from the API, so half board would need yet another field.

PASS if the reply says that breakfast per room line contradicts the decision
of one meal plan per quote. Any words, code names or ticket keys are fine.

FAIL if this problem is missing or misstated.
