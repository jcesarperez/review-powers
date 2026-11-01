import { db } from "../db";

export interface DiscountCode {
  code: string;
  percent: number;
}

export async function findCode(code: string): Promise<DiscountCode | undefined> {
  const row = await db.oneOrNone("select code, percent from discount_codes where code = $1", [code]);
  return row ?? undefined;
}

export async function applyDiscount(
  total: number,
  code: string | undefined,
): Promise<number> {
  if (!code) return total;
  const discount = await findCode(code);
  return total * (1 - discount!.percent / 100);
}
