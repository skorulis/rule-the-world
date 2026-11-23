import { sql } from "drizzle-orm";
import { NextResponse } from "next/server";
import { user } from "@/db/auth-schema";
import { requireSession, serverError } from "@/lib/api/route-helpers";
import { db } from "@/lib/db";
import { randomPowerUp } from "@/lib/powerups/powerups";

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  try {
    const session = await requireSession(request);
    if (session instanceof NextResponse) return session;

    const powerup = randomPowerUp();
    const key = String(powerup.id);
    const rows = await db.execute<{ powerups: Record<string, number> }>(sql`
      update ${user}
      set "powerups" = jsonb_set(
        coalesce(${user.powerups}, '{}'::jsonb),
        ${`{${key}}`}::text[],
        to_jsonb(coalesce((${user.powerups} ->> ${key})::int, 0) + 1)
      )
      where ${user.id} = ${session.user.id}
      returning ${user.powerups} as powerups
    `);
    return NextResponse.json({
      powerup,
      powerups: rows[0]?.powerups ?? { [key]: 1 },
    }, { headers: { "Cache-Control": "private, no-store" } });
  } catch (error) {
    return serverError("Debug add powerup failed", error, "Unable to add power-up");
  }
}
