import { confirmQuote } from "../src/quotes/confirm";
import * as holds from "../src/inventory/holds";
import * as credit from "../src/credit/credit";
import * as repository from "../src/quotes/repository";

const quote = {
  id: "q1",
  customerId: "c1",
  arrival: "2026-12-01",
  rooms: [{ roomType: "Double" as const, count: 2, nights: 3, nightlyRate: 100 }],
  legacyTotal: 600,
};

test("a customer without enough credit holds no rooms", async () => {
  jest.spyOn(repository, "findQuote").mockResolvedValue(quote);
  jest.spyOn(credit, "debitDeposit").mockRejectedValue(new Error("not enough credit"));
  const hold = jest.spyOn(holds, "holdRooms").mockResolvedValue();

  await expect(confirmQuote("q1")).rejects.toThrow("not enough credit");
  expect(hold).not.toHaveBeenCalled();
});
