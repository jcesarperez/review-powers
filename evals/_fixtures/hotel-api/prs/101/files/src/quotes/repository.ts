import { Quote, toAccommodationBlocks } from "./quote";
import { db } from "../db";

export async function findQuote(id: string): Promise<Quote | undefined> {
  const row = await db.one("select * from quotes where id = $1", [id]);
  if (!row) return undefined;
  return {
    id: row.id,
    customerId: row.customer_id,
    arrival: row.arrival,
    rooms: row.rooms,
    accommodationBlocks: toAccommodationBlocks(row.rooms),
    legacyTotal: row.legacy_total ?? null,
    discountCode: row.discount_code ?? undefined,
  };
}
