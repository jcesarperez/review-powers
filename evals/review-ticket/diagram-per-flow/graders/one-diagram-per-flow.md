---
type: llm
weight: 3
---

Judge only the `mermaid` diagrams in the reply, not the findings.

The ticket has two flows. Confirming a quote: the API requests each block
from the PMS, stores the block ids and marks the quote `pending`. Later, the
PMS calls a webhook (`block.created`): the API updates the block and marks
the quote `confirmed` once all its blocks exist.

PASS if the reply shows these two flows in separate diagrams, one per flow.
Extra diagrams (the quote's lifecycle, the table) are fine.

FAIL if both flows are drawn in one diagram, if only one of them is drawn,
or if there is no diagram.
