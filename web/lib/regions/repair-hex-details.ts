import { and, eq, sql } from "drizzle-orm";
import { hexDetails } from "@/db/schema";

type Details = typeof hexDetails.$inferSelect;
export type ClassificationChange = { before: Details; after: Details };
export type ClassificationStore = {
  lastCell(): Promise<bigint | undefined>;
  readBatch(after: bigint | undefined, through: bigint, limit: number): Promise<Details[]>;
  applyBatch(changes: ClassificationChange[]): Promise<void>;
};

const fields = ["regionCountry", "regionState", "regionSuburb"] as const;

export function classificationGuard(before: Details) {
  return and(
    eq(hexDetails.cell, before.cell),
    ...fields.map((field) => sql`${hexDetails[field]} is not distinct from ${before[field]}::bigint`),
  )!;
}

export async function repairHexDetails(
  store: ClassificationStore,
  classify: (cell: bigint) => Details,
  { apply = false, batchSize = 100, exampleLimit = 10 } = {},
) {
  if (!Number.isSafeInteger(batchSize) || batchSize < 1 || batchSize > 1000
    || !Number.isSafeInteger(exampleLimit) || exampleLimit < 0 || exampleLimit > 100) {
    throw new Error("Invalid repair batch size or example limit");
  }
  const summary = {
    mode: apply ? "apply" : "dry-run", scanned: 0, changed: 0, updated: 0,
    nullToAssigned: 0, assignedToNull: 0, reassigned: 0,
    examples: [] as ClassificationChange[],
  };
  const through = await store.lastCell();
  if (through === undefined) return summary;
  let after: bigint | undefined;
  while (true) {
    const rows = await store.readBatch(after, through, batchSize);
    if (!rows.length) break;
    if (rows.length > batchSize || rows.some((row, index) => row.cell > through
      || (index === 0 ? after !== undefined && row.cell <= after : row.cell <= rows[index - 1].cell))) {
      throw new Error("Repair store returned an invalid page");
    }
    const changes: ClassificationChange[] = [];
    for (const before of rows) {
      const after = classify(before.cell);
      if (after.cell !== before.cell) throw new Error("Classifier changed cell identity");
      const changed = fields.filter((field) => before[field] !== after[field]);
      if (!changed.length) continue;
      for (const field of changed) {
        if (before[field] === null) summary.nullToAssigned++;
        else if (after[field] === null) summary.assignedToNull++;
        else summary.reassigned++;
      }
      const change = { before, after };
      changes.push(change);
      if (summary.examples.length < exampleLimit) summary.examples.push(change);
    }
    if (apply && changes.length) {
      await store.applyBatch(changes);
      summary.updated += changes.length;
    }
    summary.scanned += rows.length;
    summary.changed += changes.length;
    after = rows[rows.length - 1].cell;
  }
  return summary;
}
