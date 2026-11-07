import { db } from "../db";
import { Quote } from "../quotes/quote";

// Rooms a confirmed quote takes out of the sellable inventory, per night.
export async function holdRooms(quote: Quote): Promise<void> {
  for (const line of quote.rooms) {
    const result = await db.result(
      `update inventory set available = available - $3
       where room_type = $1 and night >= $2 and night < $2::date + $4
         and available >= $3`,
      [line.roomType, quote.arrival, line.count, line.nights],
    );
    if (result.rowCount < line.nights) throw new Error(`${line.roomType} sold out`);
  }
}

export async function releaseRooms(quote: Quote): Promise<void> {
  for (const line of quote.rooms) {
    await db.none(
      `update inventory set available = available + $3
       where room_type = $1 and night >= $2 and night < $2::date + $4`,
      [line.roomType, quote.arrival, line.count, line.nights],
    );
  }
}
