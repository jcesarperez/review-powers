// Groups of GROUP_MIN_ROOMS rooms or more get GROUP_DISCOUNT off.
export const GROUP_MIN_ROOMS = 10;
export const GROUP_DISCOUNT = 0.05;

export async function applyDiscount(
  total: number,
  code: string | undefined,
): Promise<number> {
  if (!code) return total;
  // Only the launch code exists for now.
  return code === "LAUNCH10" ? total * 0.9 : total;
}

// The group discount does not stack with a discount code: a quote with a code
// gets the code's discount instead.
export function groupDiscount(total: number, rooms: number): number {
  return rooms >= GROUP_MIN_ROOMS ? total * (1 - GROUP_DISCOUNT) : total;
}
