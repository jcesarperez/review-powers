import { Router } from "express";
import { findQuote } from "./repository";
import { quoteTotal } from "./quote";
import { applyDiscount, groupDiscount } from "../discounts/discounts";

export const quotesRouter = Router();

quotesRouter.get("/api/v1/quotes/:quoteId", async (req, res) => {
  const quote = await findQuote(req.params.quoteId);
  if (!quote) return res.status(404).json({ error: "quote not found" });

  const subtotal = quoteTotal(quote);
  const total = quote.discountCode
    ? await applyDiscount(subtotal, quote.discountCode)
    : groupDiscount(subtotal, quote.rooms.length);

  res.json({
    id: quote.id,
    arrival: quote.arrival,
    rooms: quote.rooms,
    legacyTotal: quote.legacyTotal,
    total,
  });
});
