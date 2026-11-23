import { sql } from "drizzle-orm";
import { NextResponse } from "next/server";
import { user } from "@/db/auth-schema";
import { hexDetails, hexVisit, regionType } from "@/db/schema";
import { requireSession, serverError } from "@/lib/api/route-helpers";
import { db } from "@/lib/db";

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  try {
    const session = await requireSession(request);
    if (session instanceof NextResponse) return session;

    const rows = await db.execute<{
      region: string | null;
      kind: number | null;
      overall: number;
      visited: string;
      owned: string;
    }>(sql`
      with user_cells as (
        select ${hexVisit.cell} as cell,
          ${hexVisit.total} > 0 as visited,
          ${hexVisit.score} > coalesce((
            select max(rival.score) from ${hexVisit} as rival
            where rival.cell = ${hexVisit.cell} and rival.user_id <> ${session.user.id}
          ), 0) as owned
        from ${hexVisit}
        where ${hexVisit.userId} = ${session.user.id}
      ), region_counts as (
        select membership.region, membership.kind,
          count(*) filter (where user_cells.visited)::text as visited,
          count(*) filter (where user_cells.owned and user_cells.visited)::text as owned
        from user_cells
        join ${hexDetails} on ${hexDetails.cell} = user_cells.cell
        cross join lateral (values
          (${hexDetails.regionCountry}, ${sql.raw(String(regionType.country))}),
          (${hexDetails.regionState}, ${sql.raw(String(regionType.state))}),
          (${hexDetails.regionSuburb}, ${sql.raw(String(regionType.suburb))})
        ) as membership(region, kind)
        where membership.region is not null
        group by membership.region, membership.kind
      )
      select region::text, kind, 0 as overall, visited, owned from region_counts
      union all
      select null, null, 1,
        count(*) filter (where visited)::text as visited,
        count(*) filter (where owned and visited)::text as owned
      from user_cells
      order by overall desc, region nulls first
    `);
    const total = rows.find((row) => Number(row.overall) === 1);
    const kinds = new Map<number, string>([
      [regionType.country, "country"],
      [regionType.state, "state"],
      [regionType.suburb, "suburb"],
    ]);
    const regions = rows.flatMap((row) => {
      const id = Number(row.region);
      const kind = row.kind === null ? undefined : kinds.get(Number(row.kind));
      return Number(row.overall) === 0 && Number.isSafeInteger(id) && id > 0 && kind !== undefined
        ? [{ id, kind, visited: Number(row.visited), owned: Number(row.owned) }]
        : [];
    });
    const powerupRows = await db.execute<{ powerups: Record<string, number> | null }>(sql`
      select ${user.powerups} as powerups from ${user} where ${user.id} = ${session.user.id}
    `);
    const powerups = powerupRows[0]?.powerups ?? {};
    const { id, name, email, createdAt } = session.user;
    return NextResponse.json({
      user: { id, name, email, createdAt },
      visited: Number(total?.visited ?? 0),
      owned: Number(total?.owned ?? 0),
      regions,
      powerups,
    }, { headers: { "Cache-Control": "private, no-store" } });
  } catch {
    return serverError("Profile summary failed", undefined, "Unable to load profile");
  }
}
