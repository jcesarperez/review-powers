import { db } from "../db";
import { findQuote } from "./repository";
import { toPmsBlocks } from "../pms/blocks";
import { requestBlock } from "../pms/client";

// Confirming a quote asks the PMS for its blocks and marks it pending. The PMS
// webhook (src/pms/webhooks.ts) marks it confirmed once every block exists.
export async function confirmQuote(quoteId: string): Promise<void> {
  const quote = await findQuote(quoteId);
  if (!quote) throw new Error(`quote ${quoteId} not found`);

  for (const block of toPmsBlocks(quote)) {
    const blockId = await requestBlock(block);
    await db.none(
      "insert into pms_blocks (block_id, quote_id, status) values ($1, $2, 'requested')",
      [blockId, quoteId],
    );
  }
  await db.none("update quotes set status = 'pending' where id = $1", [quoteId]);
}
