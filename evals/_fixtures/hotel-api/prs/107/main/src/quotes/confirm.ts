import { db } from "../db";
import { findQuote } from "./repository";
import { toPmsBlocks } from "../pms/blocks";
import { reserveBlocks } from "../pms/client";

// Confirming a quote reserves its rooms in the PMS, then marks it confirmed.
export async function confirmQuote(quoteId: string): Promise<void> {
  const quote = await findQuote(quoteId);
  if (!quote) throw new Error(`quote ${quoteId} not found`);

  await reserveBlocks(toPmsBlocks(quote));
  await db.none("update quotes set status = 'confirmed' where id = $1", [quoteId]);
}
