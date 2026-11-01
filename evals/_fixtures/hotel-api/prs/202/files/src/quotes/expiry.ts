import { Quote } from "./quote";

export const QUOTE_VALIDITY_DAYS = 14;

// A quote can be accepted for QUOTE_VALIDITY_DAYS after it was created.
export function isExpired(quote: Quote, now: Date): boolean {
  const created = new Date(quote.createdAt);
  const ageDays = (now.getTime() - created.getTime()) / 86_400_000;
  return ageDays > QUOTE_VALIDITY_DAYS;
}
