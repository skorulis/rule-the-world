import { count, sql } from "drizzle-orm";
import { NextResponse } from "next/server";
import { hexDetails, hexVisit, regionType } from "@/db/schema";
import { db } from "@/lib/db";

export const dynamic = "force-dynamic";

export async function GET() {
  const [[{ value: hexVisits }], [{ value: hexRegions }], regions] = await Promise.all([
    db.select({ value: count() }).from(hexVisit),
    db.select({ value: count() }).from(hexDetails),
    db.execute<{ region: string; kind: number; hexes: string }>(sql`
      select membership.region::text as region, membership.kind, count(*)::text as hexes
      from ${hexDetails}
      cross join lateral (values
        (${hexDetails.regionCountry}, ${sql.raw(String(regionType.country))}),
        (${hexDetails.regionState}, ${sql.raw(String(regionType.state))})
      ) as membership(region, kind)
      where membership.region is not null
      group by membership.region, membership.kind
      order by count(*) desc
    `),
  ]);
  return NextResponse.json({
    hexVisits, hexRegions,
    regions: regions.map(({ region, kind, hexes }) => ({ region, kind, hexes: Number(hexes) })),
  });
}
