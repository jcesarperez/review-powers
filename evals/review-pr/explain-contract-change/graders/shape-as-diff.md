---
type: llm
weight: 2
---

PASS if the change to what the quote endpoint returns is shown as a `diff`
code block of the response *shape*: field names with their types and whether
they can be empty, unchanged lines starting with a space, added with `+`,
changed or removed with `-`. For example:

```diff
 GET /api/v1/quotes/{quoteId}
   response Quote
+    accommodationBlocks: AccommodationBlock[]  (required)
-    legacyTotal: number
+    legacyTotal: number | null
```

FAIL if the shape change is only described in prose, shown as raw JSON or as
the TypeScript source diff, or not shown at all.
