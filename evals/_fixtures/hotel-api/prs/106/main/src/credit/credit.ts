import { db } from "../db";

// Corporate customers prepay credit; a confirmed quote takes its deposit from it.
export async function debitDeposit(customerId: string, amount: number): Promise<void> {
  const result = await db.result(
    `update customer_credit set balance = balance - $2
     where customer_id = $1 and balance >= $2`,
    [customerId, amount],
  );
  if (result.rowCount === 0) throw new Error("not enough credit");
}

export async function refundDeposit(customerId: string, amount: number): Promise<void> {
  await db.none(
    "update customer_credit set balance = balance + $2 where customer_id = $1",
    [customerId, amount],
  );
}
