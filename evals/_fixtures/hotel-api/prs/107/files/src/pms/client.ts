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

// Asks the PMS to create the block in the background. It answers right away
// with the block id; the block.created webhook says how it went.
export async function requestBlock(block: PmsBlock): Promise<string> {
  const res = await fetch(`${process.env.PMS_URL}/availability-blocks?async=true`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(block),
  });
  if (res.status !== 202) throw new Error(`PMS answered ${res.status}`);
  const { blockId } = await res.json();
  return blockId;
}
