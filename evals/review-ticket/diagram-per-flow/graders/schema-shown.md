---
type: llm
---

Judge only whether the reply shows the stored data the ticket added.

The PR adds a table, `pms_blocks` (`block_id` primary key, `quote_id`
referencing `quotes`, `status`), one row per block requested for a quote.

PASS if the reply shows this table as a view, an `erDiagram` or a `diff` of
the table's columns, with its link to quotes (the `quote_id` reference or a
quote-to-blocks relation).

FAIL if the table is only named in prose, or not shown at all.
