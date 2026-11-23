import { sql } from "drizzle-orm";
import { NextResponse } from "next/server";
import { user } from "@/db/auth-schema";
import { jsonError, requireSession, serverError } from "@/lib/api/route-helpers";
import { db } from "@/lib/db";
import { dailyRewardRarity, utcDay } from "@/lib/powerups/daily-reward";
import { randomPowerUp } from "@/lib/powerups/powerups";

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  try {
    const session = await requireSession(request);
    if (session instanceof NextResponse) return session;

    const today = utcDay(new Date());
    const powerup = randomPowerUp(Math.random, dailyRewardRarity);
    const key = String(powerup.id);
    const rows = await db.execute<{ powerups: Record<string, number> }>(sql`
      update ${user}
      set "powerups" = jsonb_set(
        coalesce(${user.powerups}, '{}'::jsonb),
        ${`{${key}}`}::text[],
        to_jsonb(coalesce((${user.powerups} ->> ${key})::int, 0) + 1)
      ),
      "daily_reward_day" = ${today}::date
      where ${user.id} = ${session.user.id}
        and (${user.dailyRewardDay} is null or ${user.dailyRewardDay} < ${today}::date)
      returning ${user.powerups} as powerups
    `);
    if (!rows[0]) return jsonError("Daily reward already claimed", 409);
    return NextResponse.json({
      powerup,
      powerups: rows[0].powerups,
    }, { headers: { "Cache-Control": "private, no-store" } });
  } catch (error) {
    return serverError("Daily reward failed", error, "Unable to claim daily reward");
  }
}
