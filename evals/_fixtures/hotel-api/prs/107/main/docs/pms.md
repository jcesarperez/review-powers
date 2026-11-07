# The hotel's PMS

We reserve rooms in the hotel's PMS as availability blocks.

## Creating a block

`POST /availability-blocks` creates the block and answers `201` when it
exists. At peak times this can take 20 seconds or more.

`POST /availability-blocks?async=true` answers `202` with `{ "blockId": "..." }`
right away and creates the block in the background. When the block exists, the
PMS calls our webhook (see below), usually within 50 ms.

## Webhooks

The PMS posts `{ "event": "block.created", "blockId": "...", "status":
"confirmed" | "rejected" }` to `POST /webhooks/pms`. A `2xx` answer acknowledges
the event. The PMS retries only after a non-`2xx` answer, up to 5 times over 10
minutes.
