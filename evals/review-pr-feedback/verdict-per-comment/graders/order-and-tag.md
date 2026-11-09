---
type: llm
weight: 1
---

Judge only the order of the findings and their tags; the verdicts are graded
elsewhere.

The comment that costs most if ignored is `maria-k`'s on `releaseBlocks`: a
refused PMS release goes unnoticed and the rooms stay blocked. The `qoute`
typo costs least.

PASS if the `releaseBlocks` finding comes before the typo, and every finding
starts with a short tag naming what it is about (e.g. Bug, Docs, Scope).

FAIL if the typo comes first, or any finding has no tag.
