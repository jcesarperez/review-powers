import { toPmsBlocks } from "../src/pms/blocks";

test("merges lines of the same room type into one block", () => {
  const blocks = toPmsBlocks({
    id: "q1",
    customerId: "c1",
    arrival: "2026-12-01",
    legacyTotal: 0,
    rooms: [
      { roomType: "Double", count: 2, nights: 3, nightlyRate: 100 },
      { roomType: "Double", count: 1, nights: 3, nightlyRate: 100 },
    ],
  });

  expect(blocks).toEqual([
    { roomType: "Double", rooms: 3, nights: 3, arrival: "2026-12-01" },
  ]);
});
