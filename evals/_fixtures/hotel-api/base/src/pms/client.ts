import { PmsBlock } from "./blocks";

export async function reserveBlocks(blocks: PmsBlock[]): Promise<void> {
  for (const block of blocks) {
    await fetch(`${process.env.PMS_URL}/availability-blocks`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(block),
    });
  }
}
