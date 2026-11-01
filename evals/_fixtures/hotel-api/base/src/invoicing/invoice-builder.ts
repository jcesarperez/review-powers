import { findQuote } from "../quotes/repository";

export interface InvoiceLine {
  description: string;
  amount: string;
}

export async function buildInvoice(quoteId: string): Promise<InvoiceLine[]> {
  const quote = await findQuote(quoteId);
  if (!quote) throw new Error(`quote ${quoteId} not found`);

  return [
    {
      description: `Accommodation, arrival ${quote.arrival}`,
      amount: quote.legacyTotal.toFixed(2),
    },
  ];
}
