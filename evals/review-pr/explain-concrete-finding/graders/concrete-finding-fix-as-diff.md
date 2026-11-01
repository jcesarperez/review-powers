---
type: llm
weight: 2
---

Judge only the unknown-discount-code finding; blocks in other findings don't
count.

That finding is already concrete: one input, one wrong result. It should be
explained in a sentence or two of plain text plus the code location. The fix
is one line, and the clearest way to show it is a small `diff` of the code it
changes, e.g.:

```diff
   const discount = await findCode(code);
+  if (!discount) return total;
   return total * (1 - discount!.percent / 100);
```

PASS if the finding is explained that briefly and the proposed fix is shown as
a small `diff`, with no call tree, sequence diagram, file tree or other block
for that finding.
FAIL if the finding is missing, the fix is not shown as a `diff`, or the
finding carries a call tree, diagram, file tree or other explanatory block.
