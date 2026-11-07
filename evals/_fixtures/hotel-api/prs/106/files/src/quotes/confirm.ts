import { db } from "../db";
import { findQuote } from "./repository";
import { quoteTotal } from "./quote";
import { holdRooms } from "../inventory/holds";
import { debitDeposit } from "../credit/credit";

export const DEPOSIT_SHARE = 0.3;

// Confirming a quote takes a 30% deposit from the customer's credit, holds its
// rooms, and marks it confirmed. The deposit comes first, so a customer without
// enough credit never takes rooms out of the inventory.
export async function confirmQuote(quoteId: string): Promise<void> {
  const quote = await findQuote(quoteId);
  if (!quote) throw new Error(`quote ${quoteId} not found`);

  await debitDeposit(quote.customerId, quoteTotal(quote) * DEPOSIT_SHARE);
  await holdRooms(quote);

  await db.none("update quotes set status = 'confirmed' where id = $1", [quoteId]);
}
