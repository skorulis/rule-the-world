import { count, desc } from "drizzle-orm";
import { NextResponse } from "next/server";
import { hexRegion, hexVisit } from "@/db/schema";
import { db } from "@/lib/db";

export const dynamic = "force-dynamic";

export async function GET() {
  const [[{ value: hexVisits }], [{ value: hexRegions }], regions] = await Promise.all([
    db.select({ value: count() }).from(hexVisit),
    db.select({ value: count() }).from(hexRegion),
    db.select({ region: hexRegion.region, kind: hexRegion.regionType, hexes: count() }).from(hexRegion)
      .groupBy(hexRegion.region, hexRegion.regionType)
      .orderBy(desc(count())),
  ]);
  return NextResponse.json({
    hexVisits, hexRegions,
    regions: regions.map(({ region, kind, hexes }) => ({ region: region.toString(), kind, hexes })),
  });
}
