---
type: llm
---

A report where a source of feedback went unread looks the same as one where it
was empty. So the reply should say where it looked.

PASS if the reply says which places it read feedback from (inline review
comments, conversation comments, review bodies), or otherwise makes clear all
three were read, e.g. "2 inline comments, 1 conversation comment, 2 reviews".

FAIL if the reply never says where the feedback came from.
