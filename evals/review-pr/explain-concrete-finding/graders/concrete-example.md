---
type: llm
weight: 3
---

PASS if the unknown-code problem is illustrated with a concrete case with real
values, such as: "a quote saved with code `SUMMER5`, which isn't in
`discount_codes` → opening it answers 500 instead of the undiscounted total".
Any code is fine as long as the case shows the input (a quote with a code not
in the table) and the wrong result (the error).

FAIL if the problem is only explained in the abstract ("unknown codes now
throw") with no case.
