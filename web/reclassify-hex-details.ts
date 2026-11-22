import { parseArgs } from "node:util";
import { config } from "dotenv";
import { and, asc, desc, gt, lte } from "drizzle-orm";
import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import { hexDetails } from "./db/schema";
import { calculateHexDetails } from "./lib/regions/hex-details";
import { classificationGuard, repairHexDetails } from "./lib/regions/repair-hex-details";

async function main() {
  const { values } = parseArgs({
    options: {
      apply: { type: "boolean", default: false },
      "batch-size": { type: "string", default: "100" },
      help: { type: "boolean", default: false },
    },
    allowPositionals: false,
  });
  if (values.help) {
    console.log("npm run regions:repair -- [--apply] [--batch-size=100]\nDefaults to dry-run. Uses DATABASE_URL or .env.local. Apply changes only after reviewing a dry-run against the same database. Transition counts are region fields, not cells.");
    return;
  }
  const batchSize = Number(values["batch-size"]);
  if (!Number.isSafeInteger(batchSize) || batchSize < 1 || batchSize > 1000) {
    throw new Error("Batch size must be an integer between 1 and 1000");
  }
  config({ path: ".env.local", quiet: true });
  if (!process.env.DATABASE_URL) throw new Error("DATABASE_URL is not set");
  const client = postgres(process.env.DATABASE_URL, { max: 1, prepare: false });
  const db = drizzle(client);
  try {
    const summary = await repairHexDetails({
      async lastCell() {
        const [row] = await db.select({ cell: hexDetails.cell }).from(hexDetails).orderBy(desc(hexDetails.cell)).limit(1);
        return row?.cell;
      },
      readBatch(after, through, limit) {
        return db.select().from(hexDetails).where(and(
          after === undefined ? undefined : gt(hexDetails.cell, after), lte(hexDetails.cell, through),
        )).orderBy(asc(hexDetails.cell)).limit(limit);
      },
      async applyBatch(changes) {
        await db.transaction(async (tx) => {
          for (const { before, after } of changes) {
            const updated = await tx.update(hexDetails).set({
              regionCountry: after.regionCountry, regionState: after.regionState, regionSuburb: after.regionSuburb,
            }).where(classificationGuard(before)).returning({ cell: hexDetails.cell });
            if (updated.length !== 1) throw new Error(`Concurrent classification change for cell ${before.cell.toString(16)}; batch rolled back. Rerun dry-run before retrying.`);
          }
        });
      },
    }, calculateHexDetails, { apply: values.apply, batchSize });
    console.log(JSON.stringify(summary, (_, value) => typeof value === "bigint" ? value.toString() : value, 2));
  } finally {
    await client.end();
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : "Classification repair failed");
  process.exitCode = 1;
});
