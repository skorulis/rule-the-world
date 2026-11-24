import { sql } from "drizzle-orm";
import { NextResponse } from "next/server";
import { user } from "@/db/auth-schema";
import {
  jsonError,
  parsePositiveId,
  readJsonBody,
  requireSession,
  serverError,
} from "@/lib/api/route-helpers";
import { db } from "@/lib/db";
import { lootBoxDefinition } from "@/lib/lootboxes";
import { randomPowerUp } from "@/lib/powerups/powerups";

export const dynamic = "force-dynamic";

const MAX_BOXES_PER_PURCHASE = 10;

export async function POST(request: Request) {
  try {
    const session = await requireSession(request);
    if (session instanceof NextResponse) return session;

    const body = await readJsonBody(request);
    if (body instanceof NextResponse) return body;

    const boxId = parsePositiveId(body.box);
    const box = boxId == null ? undefined : lootBoxDefinition(boxId);
    if (!box) return jsonError("Unknown loot box", 404);

    const count = typeof body.count === "number" ? body.count : Number(body.count);
    if (!Number.isInteger(count) || count < 1 || count > MAX_BOXES_PER_PURCHASE) {
      return jsonError(`Count must be between 1 and ${MAX_BOXES_PER_PURCHASE}`, 400);
    }

    const rewards = Array.from({ length: count }, () =>
      randomPowerUp(Math.random, box.rarity));
    const grants = new Map<string, number>();
    for (const reward of rewards) {
      const key = String(reward.id);
      grants.set(key, (grants.get(key) ?? 0) + 1);
    }
    const values = sql.join(
      [...grants.entries()].map(([key, cnt]) => sql`(${key}::text, ${cnt}::int)`),
      sql`, `,
    );
    const total = box.cost * count;

    const rows = await db.execute<{ coins: number; powerups: Record<string, number> }>(sql`
      update ${user}
      set "coins" = coalesce(${user.coins}, 0) - ${total},
        "powerups" = (
          select coalesce(${user.powerups}, '{}'::jsonb) || jsonb_object_agg(grants.key, grants.total)
          from (
            select v.key, v.cnt + coalesce((${user.powerups} ->> v.key)::int, 0) as total
            from (values ${values}) as v(key, cnt)
          ) as grants
        )
      where ${user.id} = ${session.user.id}
        and coalesce(${user.coins}, 0) >= ${total}
      returning ${user.coins} as coins, ${user.powerups} as powerups
    `);
    if (!rows[0]) return jsonError("Not enough coins", 409);
    return NextResponse.json({
      rewards,
      powerups: rows[0].powerups,
      coins: rows[0].coins,
    }, { headers: { "Cache-Control": "private, no-store" } });
  } catch (error) {
    return serverError("Loot box purchase failed", error, "Unable to purchase loot box");
  }
}
