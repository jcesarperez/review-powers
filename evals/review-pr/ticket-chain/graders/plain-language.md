---
type: llm
weight: 2
---

Judge only how the findings are written, not whether they are right.

The reader is a developer who has never seen this codebase. General software
and code-review vocabulary (diff, CI, migration, inline comment, HTTP status)
and the product's own domain terms need no explanation. What must be clear is
the cause: what goes wrong, or why it doesn't, and why.

Judge the explanation of each finding. Evidence and recommendation lines that
follow it (`file:line`, "Recommend: ...") are not judged.

PASS if every finding in the reply:
- says what happens and why in everyday words first, with any technical name
  (field, file, function) after it, in backticks;
- uses short sentences.

FAIL if any finding leads with code identifiers or file paths before saying
what happens, or leaves the cause to code identifiers (e.g. only "`total` is
now nullable" without saying what that does to whom).
