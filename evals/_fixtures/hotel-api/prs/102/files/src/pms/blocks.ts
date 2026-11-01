import { Quote } from "../quotes/quote";

// One availability block per room type, sent to the PMS when a quote is confirmed.
// The PMS charges a fee per block, so lines of the same room type are merged.
export interface PmsBlock {
  roomType: string;
  rooms: number;
  nights: number;
  arrival: string;
}

export function toPmsBlocks(quote: Quote): PmsBlock[] {
  const byType = new Map<string, PmsBlock>();

  for (const line of quote.rooms) {
    const existing = byType.get(line.roomType);
    if (existing) {
      existing.rooms += line.count;
    } else {
      byType.set(line.roomType, {
        roomType: line.roomType,
        rooms: line.count,
        nights: line.nights,
        arrival: quote.arrival,
      });
    }
  }

  return [...byType.values()];
}
