## What it is

Guests see what a rate includes. 2 PRs in hotel-api, 1 in web.

## To do

1. **Contract drift** in `src/rates/rate.ts:3`, see [PR 1](https://github.com/acme/hotel-api/pull/1).
   - today: the panel shows "Invalid Date"
   - done when: it shows "open-ended"
     on every open-ended block
2. Remove the leftover flag https://github.com/acme/web/pull/6.

## Owed, not code

- [ ] DEV check by Ana
- [x] QA evidence
  - recorded in the ticket
  - [ ] nested follow-up

```diff
- legacyTotal: decimal?
+ shipments: Shipment[]
```

---

Discarded: caching (no measured cost).
