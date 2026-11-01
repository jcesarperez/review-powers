import { db } from "../db";
import { findQuote } from "./repository";
import { toPmsBlocks } from "../pms/blocks";
import { releaseBlocks } from "../pms/client";

// Cancels a quote and gives its rooms back to the PMS.
export async function cancelQuote(id: string): Promise<boolean> {
  const quote = await findQuote(id);
  if (!quote) return false;

  await db.none(
    `update quotes set status = 'cancelled', cancelled_at = now()
     where id = $1`,
    [id],
  );
  await releaseBlocks(toPmsBlocks(quote));
  return true;
}
