export type RoomType = "Single" | "Double" | "Suite";

export interface RoomLine {
  roomType: RoomType;
  count: number;
  nights: number;
  nightlyRate: number;
}

export interface Quote {
  id: string;
  customerId: string;
  arrival: string;
  createdAt: string;
  rooms: RoomLine[];
  legacyTotal: number;
  discountCode?: string;
}

export function quoteTotal(quote: Quote): number {
  return quote.rooms.reduce(
    (sum, line) => sum + line.count * line.nights * line.nightlyRate,
    0,
  );
}
