---
type: llm
weight: 3
---

The PR's feedback is spread over three places. Each point below must get its
own verdict or recommendation in the reply:

1. Inline, `maria-k`: the web app only handles 404, so the new 410 for an
   expired quote would show a generic error screen.
2. Inline, `maria-k`: should `ageDays > 14` be `>=`?
3. Conversation comment, `tom-qa`: will a stay whose quote is older than 14
   days still be invoiced?
4. Bot review body, `acme-review-bot[bot]`: `86_400_000` is a magic number;
   extract a constant like `MS_PER_DAY`.
5. Bot review body, `acme-review-bot[bot]`: `isExpired` has no tests; add
   boundary cases.

`maria-k`'s review body ("main thing is the 410, see inline") adds no new
point and need not be listed separately.

PASS if all five points are present, each with a verdict or recommendation.
FAIL if any is missing or only mentioned without saying what to do about it.
