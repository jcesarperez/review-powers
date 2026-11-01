---
type: llm
weight: 2
---

Judge only how the verdicts are written, not whether they are right.

PASS if every verdict in the reply:
- says what the comment means for the behaviour in everyday words first, with
  any technical name (field, file, function) after it, in backticks;
- uses short sentences;
- explains or avoids jargon a newcomer would not know (e.g. 4xx, idempotent,
  audit trail, magic number, boundary case).

FAIL if any verdict leads with code identifiers or file paths before saying
what happens, or relies on unexplained jargon.
