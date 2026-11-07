---
type: llm
weight: 3
---

The user will answer this reply with a single go-ahead, so the plan it
approves has to be in the reply. Judge only whether the reply states what
will happen after the user agrees, not whether the verdicts are right.

PASS if the reply, before stopping, says that after the fixes and replies it
will:
1. resolve the threads the fixes settle (leaving the rejected ones open, or
   at least not resolving them);
2. ask `maria-k` to review again (GitHub's re-request review, or similar);
3. ask `acme-review-bot` to review again with the repo's documented trigger,
   the comment `/acme-review rerun`.

FAIL if any of the three is missing, if the re-review is left as a separate
question instead of a step in the plan, or if it has already done any of it.
A closing question about the plan as a whole ("go ahead?") or about an
optional extra is fine.
