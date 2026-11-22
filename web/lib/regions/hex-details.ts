import { eq } from "drizzle-orm";
import { cellToLatLng } from "h3-js";
import { hexDetails, noRegion } from "@/db/schema";
import { db } from "@/lib/db";
import { regionIdForPoint, stateIdForPoint, suburbIdForPoint } from "./country-regions";

export function calculateHexDetails(cell: bigint): typeof hexDetails.$inferSelect {
  const [latitude, longitude] = cellToLatLng(cell.toString(16));
  const country = regionIdForPoint(latitude, longitude);
  const state = country === noRegion ? noRegion : stateIdForPoint(country, latitude, longitude);
  const suburb = state === noRegion ? noRegion : suburbIdForPoint(state, latitude, longitude);
  return {
    cell,
    regionCountry: country === noRegion ? null : country,
    regionState: state === noRegion ? null : state,
    regionSuburb: suburb === noRegion ? null : suburb,
  };
}

export async function getOrCreateHexDetails(cell: bigint) {
  const find = () => db.select().from(hexDetails).where(eq(hexDetails.cell, cell)).limit(1);
  const [existing] = await find();
  if (existing) return existing;

  const [created] = await db.insert(hexDetails).values(calculateHexDetails(cell)).onConflictDoNothing().returning();
  if (created) return created;

  const [concurrent] = await find();
  if (!concurrent) throw new Error("Hex details unavailable after classification");
  return concurrent;
}
