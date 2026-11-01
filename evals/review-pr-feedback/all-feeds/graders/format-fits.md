---
type: llm
weight: 2
---

Judge only the form of the reply, not whether the verdicts are right.

A "block" here means a fenced code block (```) of any kind. Headings, bullet
lists, bold text, horizontal rules and inline `code` are not blocks.

The right form for this PR: each verdict is a few short sentences. The `>=`
question is best settled with one concrete case with dates and times, in
prose or a small `text` block. Nothing here changes a shape across services,
so no `diff` of an API shape, `mermaid` diagram or file tree is needed.

PASS if:
- every block comes right after a short sentence saying what it shows (a
  heading alone does not count);
- the reply uses at most two kinds of block;
- there is no `mermaid` diagram, no file tree and no raw JSON.

FAIL if any of these is broken.
