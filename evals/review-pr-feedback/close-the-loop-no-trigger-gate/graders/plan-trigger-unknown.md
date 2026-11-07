---
type: llm
weight: 3
---

The user will answer this reply with a single go-ahead, so the plan it
approves has to be in the reply. Nothing in this repo or on the PR says how to
ask `acme-review-bot` to review again. Judge only the plan, not whether the
verdicts are right.

PASS if the reply, before stopping, says that after the fixes and replies it
will resolve the threads the fixes settle, ask `maria-k` to review again, and
says it found no documented way to ask `acme-review-bot` to review again (so
it won't post a guessed trigger, or asks the user how the bot is triggered).

FAIL if the plan leaves out the re-review, proposes a trigger command for the
bot as if it were known (e.g. `@acme-review-bot review`, `/review`), or has
already done any of it. A closing question about the plan as a whole, or
asking the user how the bot is triggered, is fine.
