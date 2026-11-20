import { eq, sql, sum } from "drizzle-orm";
import { alias } from "drizzle-orm/pg-core";
import { NextResponse } from "next/server";
import { hexVisit } from "@/db/schema";
import { requireSession, serverError } from "@/lib/api/route-helpers";
import { db } from "@/lib/db";

export async function GET(request: Request) {
  try {
    const session = await requireSession(request);
    if (session instanceof NextResponse) return session;
    const cellVisit = alias(hexVisit, "cell_visit");
    const rows = await db.select({
      cell: hexVisit.cell,
      total: hexVisit.total,
      lastVisit: hexVisit.lastVisit,
      score: hexVisit.score,
      lastScore: hexVisit.lastScore,
      totalVisits: sum(cellVisit.total),
      rivalScore: sql<string | null>`max(${cellVisit.score}) filter (where ${cellVisit.userId} <> ${session.user.id})`,
    }).from(hexVisit)
      .innerJoin(cellVisit, eq(cellVisit.cell, hexVisit.cell))
      .where(eq(hexVisit.userId, session.user.id))
      .groupBy(hexVisit.userId, hexVisit.cell, hexVisit.total, hexVisit.lastVisit, hexVisit.score, hexVisit.lastScore)
      .orderBy(hexVisit.cell);
    return NextResponse.json({
      visits: rows.map((visit) => ({
        totalVisits: Number(visit.totalVisits ?? 0),
        rivalScore: Number(visit.rivalScore ?? 0),
        userVisit: {
          cell: visit.cell,
          total: visit.total,
          lastVisit: visit.lastVisit.toISOString(),
          score: Number(visit.score),
          lastScore: Number(visit.lastScore),
        },
      })),
    }, { headers: { "Cache-Control": "private, no-store" } });
  } catch {
    return serverError("Visit download failed", undefined, "Unable to download visits");
  }
}
