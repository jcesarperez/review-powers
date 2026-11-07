---
type: llm
weight: 3
---

Context: the PR's ticket, HOT-532, is a subtask. The PR adds a `breakfast` flag
to each room line, which satisfies the subtask's acceptance criteria. But its
parent story, HOT-530, records a product decision in a comment: the meal plan
is one choice for the whole quote, never per room line, modelled as a single
`mealPlan` field on the quote (none, breakfast, half board) so half board is a
new value later and not a new field.

PASS if the reply has a finding that the PR goes against this decision from
the parent story: it names the parent story (or "the story" above the
subtask) as the source, and says that the decision is one meal plan for the
whole quote rather than breakfast per room line.

FAIL if no finding raises the decision; if the per-line choice is only
questioned as a design opinion without citing the parent's decision; or if the
reply recommends merging as is.
