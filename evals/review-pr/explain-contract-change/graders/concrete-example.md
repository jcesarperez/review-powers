---
type: llm
weight: 3
---

PASS if the invoicing problem is illustrated with a concrete case with real
values, such as: "a quote created after the deploy has `legacyTotal: null` →
`buildInvoice` calls `null.toFixed(2)` and throws, so that quote can't be
invoiced". Any values are fine as long as the case shows the input (a new
quote, its empty total) and the wrong result (the invoice fails).

FAIL if the problem is only explained in the abstract ("invoicing reads a
field that can now be null") with no case.
