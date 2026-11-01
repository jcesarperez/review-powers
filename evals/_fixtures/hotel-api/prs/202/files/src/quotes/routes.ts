import { Router } from "express";
import { findQuote } from "./repository";
import { quoteTotal } from "./quote";
import { applyDiscount } from "../discounts/discounts";
import { isExpired } from "./expiry";

export const quotesRouter = Router();

quotesRouter.get("/api/v1/quotes/:quoteId", async (req, res) => {
  const quote = await findQuote(req.params.quoteId);
  if (!quote) return res.status(404).json({ error: "quote not found" });
  if (isExpired(quote, new Date())) return res.status(410).json({ error: "quote expired" });

  const total = await applyDiscount(quoteTotal(quote), quote.discountCode);

  res.json({
    id: quote.id,
    arrival: quote.arrival,
    rooms: quote.rooms,
    legacyTotal: quote.legacyTotal,
    total,
  });
});
