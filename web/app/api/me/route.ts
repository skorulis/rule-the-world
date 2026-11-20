import { sql } from "drizzle-orm";
import { NextResponse } from "next/server";
import { hexRegion, hexVisit } from "@/db/schema";
import { requireSession, serverError } from "@/lib/api/route-helpers";
import { db } from "@/lib/db";

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  try {
    const session = await requireSession(request);
    if (session instanceof NextResponse) return session;

    const rows = await db.execute<{
      region: string | null;
      overall: number;
      visited: string;
      owned: string;
    }>(sql`
      with user_cells as (
        select ${hexRegion.region} as region,
          ${hexVisit.score} > coalesce((
            select max(rival.score) from ${hexVisit} as rival
            where rival.cell = ${hexVisit.cell} and rival.user_id <> ${session.user.id}
          ), 0) as owned
        from ${hexVisit}
        left join ${hexRegion} on ${hexRegion.cell} = ${hexVisit.cell}
        where ${hexVisit.userId} = ${session.user.id}
      )
      select region::text, grouping(region) as overall,
        count(*)::text as visited,
        count(*) filter (where owned)::text as owned
      from user_cells
      group by grouping sets ((), (region))
      having grouping(region) = 1 or region > 0
      order by user_cells.region nulls first
    `);
    const total = rows.find((row) => Number(row.overall) === 1);
    const regions = rows.flatMap((row) => {
      const id = Number(row.region);
      return Number(row.overall) === 0 && Number.isSafeInteger(id) && id > 0
        ? [{ id, visited: Number(row.visited), owned: Number(row.owned) }]
        : [];
    });
    const { id, name, email, createdAt } = session.user;
    return NextResponse.json({
      user: { id, name, email, createdAt },
      visited: Number(total?.visited ?? 0),
      owned: Number(total?.owned ?? 0),
      regions,
    }, { headers: { "Cache-Control": "private, no-store" } });
  } catch {
    return serverError("Profile summary failed", undefined, "Unable to load profile");
  }
}
