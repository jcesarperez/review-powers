export async function applyDiscount(
  total: number,
  code: string | undefined,
): Promise<number> {
  if (!code) return total;
  // Only the launch code exists for now.
  return code === "LAUNCH10" ? total * 0.9 : total;
}
