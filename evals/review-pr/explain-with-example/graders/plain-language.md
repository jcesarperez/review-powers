---
type: llm
weight: 2
---

Judge only how the findings are written, not whether they are right.

PASS if every finding in the reply:
- says what it means for the behaviour in everyday words first, with any
  technical name (field, file, function) after it, in backticks;
- uses short sentences;
- explains or avoids jargon a newcomer would not know (e.g. nullable, DTO,
  stub, snapshot, rollout).

FAIL if any finding leads with code identifiers or file paths before saying
what happens, or relies on unexplained jargon.
