// One-off backfill: inserts state rows for hex_region cells that only have a
// country row. Idempotent — safe to re-run. Usage: npx tsx scripts/backfill-state-regions.ts
import { cellToLatLng } from "h3-js";
import { eq, ne } from "drizzle-orm";
import { hexRegion, noRegion, regionType } from "../db/schema";
import { db } from "../lib/db";
import { loadScriptEnv } from "../load-script-env";
import { stateIdForPoint } from "../lib/regions/country-regions";

const BATCH = 500;

async function main() {
  loadScriptEnv();
  const countries = await db
    .select({ cell: hexRegion.cell, region: hexRegion.region })
    .from(hexRegion)
    .where(ne(hexRegion.regionType, regionType.state));
  const classified = new Set(
    (await db.select({ cell: hexRegion.cell }).from(hexRegion)
      .where(eq(hexRegion.regionType, regionType.state))).map(({ cell }) => cell),
  );
  const rows = [];
  for (const { cell, region } of countries) {
    if (region === noRegion || classified.has(cell)) continue;
    const [latitude, longitude] = cellToLatLng(cell.toString(16));
    const state = stateIdForPoint(region, latitude, longitude);
    if (state !== noRegion) rows.push({ cell, region: state, regionType: regionType.state });
  }
  for (let i = 0; i < rows.length; i += BATCH) {
    await db.insert(hexRegion).values(rows.slice(i, i + BATCH)).onConflictDoNothing();
  }
  console.log(`Backfilled ${rows.length} state regions for ${countries.length} cells`);
  process.exit(0);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
