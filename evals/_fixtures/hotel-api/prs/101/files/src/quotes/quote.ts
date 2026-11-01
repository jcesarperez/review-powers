export type RoomType = "Single" | "Double" | "Suite";

export interface RoomLine {
  roomType: RoomType;
  count: number;
  nights: number;
  nightlyRate: number;
}

export interface AccommodationBlock {
  roomType: RoomType;
  roomNights: number;
  amount: number;
}

export interface Quote {
  id: string;
  customerId: string;
  arrival: string;
  rooms: RoomLine[];
  accommodationBlocks: AccommodationBlock[];
  // Only set on quotes created before accommodation blocks existed.
  legacyTotal: number | null;
  discountCode?: string;
}

export function quoteTotal(quote: Quote): number {
  return quote.accommodationBlocks.reduce((sum, block) => sum + block.amount, 0);
}

export function toAccommodationBlocks(rooms: RoomLine[]): AccommodationBlock[] {
  return rooms.map((line) => ({
    roomType: line.roomType,
    roomNights: line.count * line.nights,
    amount: line.count * line.nights * line.nightlyRate,
  }));
}
