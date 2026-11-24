import { sql } from "drizzle-orm";
import { NextResponse } from "next/server";
import { type RegionRanking, user } from "@/db/auth-schema";
import { jsonError, requireSession, serverError } from "@/lib/api/route-helpers";
import { db } from "@/lib/db";
import { utcDay } from "@/lib/powerups/daily-reward";
import { dailyStipend } from "@/lib/stipend";

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  try {
    const session = await requireSession(request);
    if (session instanceof NextResponse) return session;

    const rows = await db.execute<{
      rankings: RegionRanking[] | null;
      stipend_day: string | null;
    }>(sql`
      select ${user.rankings} as rankings, ${user.stipendDay}::text as stipend_day
      from ${user} where ${user.id} = ${session.user.id}
    `);
    const today = utcDay(new Date());
    if (rows[0]?.stipend_day === today) return jsonError("Stipend already collected", 409);

    const stipend = dailyStipend(rows[0]?.rankings ?? []);
    const updated = await db.execute<{ coins: number }>(sql`
      update ${user}
      set "coins" = coalesce(${user.coins}, 0) + ${stipend},
        "total_earnings" = coalesce(${user.totalEarnings}, 0) + ${stipend},
        "stipend_day" = ${today}::date
      where ${user.id} = ${session.user.id}
        and (${user.stipendDay} is null or ${user.stipendDay} < ${today}::date)
      returning ${user.coins} as coins
    `);
    if (!updated[0]) return jsonError("Stipend already collected", 409);
    return NextResponse.json({ stipend, coins: updated[0].coins }, { headers: { "Cache-Control": "private, no-store" } });
  } catch (error) {
    return serverError("Stipend collection failed", error, "Unable to collect stipend");
  }
}
