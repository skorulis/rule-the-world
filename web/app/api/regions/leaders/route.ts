import { sql } from "drizzle-orm";
import { NextResponse } from "next/server";
import { user } from "@/db/auth-schema";
import { playerRanking } from "@/db/schema";
import { jsonError, parsePositiveId, requireSession, serverError } from "@/lib/api/route-helpers";
import { db } from "@/lib/db";

export const dynamic = "force-dynamic";

const regionTypes = new Set(["country", "state", "suburb"]);

export async function GET(request: Request) {
  try {
    const session = await requireSession(request);
    if (session instanceof NextResponse) return session;

    const url = new URL(request.url);
    const type = url.searchParams.get("type");
    const id = parsePositiveId(url.searchParams.get("id"));
    if (type === null || !regionTypes.has(type) || id === null) {
      return jsonError("Invalid region", 400);
    }

    const rows = await db.execute<{ rank: number; name: string; owned: number }>(sql`
      select ${playerRanking.rankNumber} as rank, ${user.name} as name,
        ${playerRanking.ownedCount} as owned
      from ${playerRanking}
      join ${user} on ${user.id} = ${playerRanking.userId}
      where ${playerRanking.regionType} = ${type}
        and ${playerRanking.regionId} = ${id}
      order by ${playerRanking.rankNumber}, ${playerRanking.userId}
      limit 20
    `);

    return NextResponse.json(
      { leaders: rows.map((row) => ({ rank: Number(row.rank), name: row.name, owned: Number(row.owned) })) },
      { headers: { "cache-control": "private, no-store" } },
    );
  } catch (error) {
    return serverError("Region leaders fetch failed", error, "Unable to load region leaders");
  }
}
