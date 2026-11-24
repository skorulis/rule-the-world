import { sql } from "drizzle-orm";
import { NextResponse } from "next/server";
import { user } from "@/db/auth-schema";
import { jsonError, requireSession, serverError } from "@/lib/api/route-helpers";
import { db } from "@/lib/db";

export const dynamic = "force-dynamic";

const AMOUNT = 1000;

export async function POST(request: Request) {
  if (process.env.NODE_ENV !== "development") {
    return jsonError("Not found", 404);
  }
  try {
    const session = await requireSession(request);
    if (session instanceof NextResponse) return session;

    const rows = await db.execute<{ coins: number }>(sql`
      update ${user}
      set "coins" = coalesce(${user.coins}, 0) + ${AMOUNT},
        "total_earnings" = coalesce(${user.totalEarnings}, 0) + ${AMOUNT}
      where ${user.id} = ${session.user.id}
      returning ${user.coins} as coins
    `);
    return NextResponse.json({ added: AMOUNT, coins: rows[0]?.coins ?? null }, { headers: { "Cache-Control": "private, no-store" } });
  } catch (error) {
    return serverError("Cheat add money failed", error, "Unable to add coins");
  }
}
