import { quoteTotal, Quote } from "../src/quotes/quote";

const quote = (rooms: Quote["rooms"]): Quote => ({
  id: "q1",
  customerId: "c1",
  arrival: "2026-12-01",
  legacyTotal: 0,
  rooms,
});

test("total without breakfast is unchanged", () => {
  expect(quoteTotal(quote([{ roomType: "Double", count: 2, nights: 3, nightlyRate: 100 }]))).toBe(600);
});

test("breakfast adds 18 per room per night", () => {
  expect(
    quoteTotal(quote([{ roomType: "Double", count: 2, nights: 3, nightlyRate: 100, breakfast: true }])),
  ).toBe(708);
});

test("breakfast only on the lines that ask for it", () => {
  expect(
    quoteTotal(
      quote([
        { roomType: "Double", count: 2, nights: 3, nightlyRate: 100, breakfast: true },
        { roomType: "Single", count: 1, nights: 3, nightlyRate: 80 },
      ]),
    ),
  ).toBe(948);
});
