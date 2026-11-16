---
type: llm
---

Judge only the part of the reply that says what the review covered.

The review ran without its gather script: tickets came from a tracker CLI and
the PR from `gh`, found through a link in a ticket comment. HOT-531 (half
board) has no PR.

PASS if the coverage says which tickets and which PR feeds were read, and
names at least one thing it could not check or that is missing (for example
no PR for HOT-531, or no search for other PRs naming the keys).

FAIL if the coverage is missing, or reads as a complete gather with nothing
left out.
