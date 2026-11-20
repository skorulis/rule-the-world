import { and, eq, max, ne, sum } from "drizzle-orm";
import { NextResponse } from "next/server";
import { hexVisit } from "@/db/schema";
import { jsonError, requireSession, serverError } from "@/lib/api/route-helpers";
import { db } from "@/lib/db";
import { isVisitCell } from "@/lib/visits/visit-batch";

export async function GET(request: Request, ctx: RouteContext<"/api/hex-visits/[cell]">) {
  try {
    const session = await requireSession(request);
    if (session instanceof NextResponse) return session;
    const { cell: cellParam } = await ctx.params;
    if (!isVisitCell(cellParam)) return jsonError("Invalid cell", 400);
    const cell = BigInt(`0x${cellParam}`);

    const [[totals], [rival], [visit]] = await Promise.all([
      db.select({ totalVisits: sum(hexVisit.total) }).from(hexVisit)
        .where(eq(hexVisit.cell, cell)),
      db.select({ rivalScore: max(hexVisit.score) }).from(hexVisit)
        .where(and(eq(hexVisit.cell, cell), ne(hexVisit.userId, session.user.id))),
      db.select({
        cell: hexVisit.cell,
        total: hexVisit.total,
        lastVisit: hexVisit.lastVisit,
        score: hexVisit.score,
        lastScore: hexVisit.lastScore,
      }).from(hexVisit)
        .where(and(eq(hexVisit.cell, cell), eq(hexVisit.userId, session.user.id))),
    ]);

    return NextResponse.json({
      totals: totals?.totalVisits == null
        ? null
        : {
            totalVisits: Number(totals.totalVisits),
            rivalScore: Number(rival?.rivalScore ?? 0),
          },
      userVisit: visit
        ? {
            ...visit,
            cell: visit.cell.toString(16),
            lastVisit: visit.lastVisit.toISOString(),
            score: Number(visit.score),
            lastScore: Number(visit.lastScore),
          }
        : null,
    }, { headers: { "Cache-Control": "private, no-store" } });
  } catch {
    return serverError("Hex totals lookup failed", undefined, "Unable to load hexagon");
  }
}
