import { Quote } from "./quote";
import { db } from "../db";

export async function findQuote(id: string): Promise<Quote | undefined> {
  const row = await db.one("select * from quotes where id = $1", [id]);
  if (!row) return undefined;
  return {
    id: row.id,
    customerId: row.customer_id,
    arrival: row.arrival,
    createdAt: row.created_at,
    rooms: row.rooms,
    legacyTotal: row.legacy_total,
    discountCode: row.discount_code ?? undefined,
  };
}
