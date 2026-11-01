---
type: llm
weight: 2
---

The PR adds cancelling a quote. Reviewer `maria-k` commented on `releaseBlocks`
in `src/pms/client.ts`: `fetch` doesn't throw when the PMS answers with an
error, so a refused release goes unnoticed, the API still answers 204, and the
rooms stay blocked in the PMS. This is correct: the response is never checked.

PASS if the reply agrees this comment is correct and recommends fixing it in
this PR. Going further is fine (e.g. noting the quote is already marked
cancelled before the release is attempted).

FAIL if the reply rejects it, calls it unverified, recommends skipping it, or
leaves it out.
