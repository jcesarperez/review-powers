---
type: llm
weight: 3
---

Judge only whether the reply finds the problem; how it is written is graded
elsewhere.

What actually goes wrong in this PR: confirming a quote asks the PMS for a
block, and only after the PMS answers does it store the block id. The PMS
sends its "block created" webhook as soon as the block exists, often before
the id is stored. The webhook then finds no stored block, treats it as not
ours and answers success, so the PMS never retries. The quote stays "pending"
forever although its rooms are reserved.

PASS if the reply says that the webhook can arrive before the block id is
stored, gets dropped, and leaves the quote stuck as pending. Any words or code
names are fine.

FAIL if this problem is missing or misstated.
