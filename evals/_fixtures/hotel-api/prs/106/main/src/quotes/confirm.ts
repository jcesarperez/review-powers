import { db } from "../db";
import { findQuote } from "./repository";
import { quoteTotal } from "./quote";
import { holdRooms, releaseRooms } from "../inventory/holds";
import { debitDeposit } from "../credit/credit";

export const DEPOSIT_SHARE = 0.3;

// Confirming a quote holds its rooms, takes a 30% deposit from the customer's
// credit, and marks it confirmed.
export async function confirmQuote(quoteId: string): Promise<void> {
  const quote = await findQuote(quoteId);
  if (!quote) throw new Error(`quote ${quoteId} not found`);

  await holdRooms(quote);
  try {
    await debitDeposit(quote.customerId, quoteTotal(quote) * DEPOSIT_SHARE);
  } catch (err) {
    // No deposit, no rooms: give them back to the inventory.
    await releaseRooms(quote);
    throw err;
  }

  await db.none("update quotes set status = 'confirmed' where id = $1", [quoteId]);
}
