import { Router } from "express";
import { db } from "../db";

export const pmsWebhooksRouter = Router();

// The PMS calls this when a block requested with requestBlock exists.
pmsWebhooksRouter.post("/webhooks/pms", async (req, res) => {
  const { event, blockId, status } = req.body;
  if (event !== "block.created") return res.sendStatus(204);

  const block = await db.oneOrNone(
    "select quote_id from pms_blocks where block_id = $1",
    [blockId],
  );
  // Not a block we asked for.
  if (!block) return res.sendStatus(204);

  await db.none("update pms_blocks set status = $2 where block_id = $1", [blockId, status]);

  const open = await db.one(
    "select count(*)::int as n from pms_blocks where quote_id = $1 and status <> 'confirmed'",
    [block.quote_id],
  );
  if (open.n === 0) {
    await db.none("update quotes set status = 'confirmed' where id = $1", [block.quote_id]);
  }
  res.sendStatus(204);
});
