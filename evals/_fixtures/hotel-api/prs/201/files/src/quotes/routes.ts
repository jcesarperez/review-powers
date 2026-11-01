import { Router } from "express";
import { findQuote } from "./repository";
import { quoteTotal } from "./quote";
import { applyDiscount } from "../discounts/discounts";
import { cancelQuote } from "./cancel";

export const quotesRouter = Router();

quotesRouter.get("/api/v1/quotes/:quoteId", async (req, res) => {
  const quote = await findQuote(req.params.quoteId);
  if (!quote) return res.status(404).json({ error: "quote not found" });

  const total = await applyDiscount(quoteTotal(quote), quote.discountCode);

  res.json({
    id: quote.id,
    arrival: quote.arrival,
    rooms: quote.rooms,
    legacyTotal: quote.legacyTotal,
    total,
  });
});

quotesRouter.post("/api/v1/quotes/:quoteId/cancel", async (req, res) => {
  const cancelled = await cancelQuote(req.params.quoteId);
  if (!cancelled) return res.status(404).json({ error: "qoute not found" });
  res.status(204).end();
});
