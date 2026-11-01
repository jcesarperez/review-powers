import { Quote } from "../quotes/quote";

// One availability block per room line, sent to the PMS when a quote is confirmed.
export interface PmsBlock {
  roomType: string;
  rooms: number;
  nights: number;
  arrival: string;
}

export function toPmsBlocks(quote: Quote): PmsBlock[] {
  return quote.rooms.map((line) => ({
    roomType: line.roomType,
    rooms: line.count,
    nights: line.nights,
    arrival: quote.arrival,
  }));
}
