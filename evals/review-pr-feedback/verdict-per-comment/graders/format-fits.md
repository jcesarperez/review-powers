---
type: llm
weight: 2
---

Judge only the form of the reply, not whether the verdicts are right.

A "block" here means a fenced code block (```) of any kind. Headings, bullet
lists, bold text, horizontal rules and inline `code` are not blocks.

The right form for this PR: each verdict is a few short sentences. The PMS
release is best shown with one concrete case (e.g. "cancel quote Q-17 → the
PMS answers 500 → the API still answers 204 → the 2 Doubles stay blocked"),
in prose or a small `text` block. The false-alarm `where` may quote the two
lines of SQL. The typo and the out-of-scope suggestion are already concrete
and need no block at all.

PASS if:
- every block comes right after a short sentence saying what it shows (a
  heading alone does not count);
- the reply uses at most two kinds of block;
- the typo and the out-of-scope suggestion get no block;
- there is no raw JSON and no `mermaid` diagram unless it shows an interaction
  between services that prose couldn't say in two sentences.

FAIL if any of these is broken.
