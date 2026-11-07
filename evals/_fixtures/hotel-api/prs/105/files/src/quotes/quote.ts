export type RoomType = "Single" | "Double" | "Suite";

export const BREAKFAST_PRICE_PER_ROOM_NIGHT = 18;

export interface RoomLine {
  roomType: RoomType;
  count: number;
  nights: number;
  nightlyRate: number;
  breakfast?: boolean;
}

export interface Quote {
  id: string;
  customerId: string;
  arrival: string;
  rooms: RoomLine[];
  legacyTotal: number;
  discountCode?: string;
}

export function quoteTotal(quote: Quote): number {
  return quote.rooms.reduce((sum, line) => {
    const nightly = line.nightlyRate + (line.breakfast ? BREAKFAST_PRICE_PER_ROOM_NIGHT : 0);
    return sum + line.count * line.nights * nightly;
  }, 0);
}
