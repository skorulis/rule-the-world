import { eq } from "drizzle-orm";
import { NextResponse } from "next/server";
import { hexVisit } from "@/db/schema";
import { requireSession, serverError } from "@/lib/api/route-helpers";
import { db } from "@/lib/db";

export async function GET(request: Request) {
  try {
    const session = await requireSession(request);
    if (session instanceof NextResponse) return session;
    const rows = await db.select({
      cell: hexVisit.cell,
      total: hexVisit.total,
      lastVisit: hexVisit.lastVisit,
      score: hexVisit.score,
      lastScore: hexVisit.lastScore,
    }).from(hexVisit).where(eq(hexVisit.userId, session.user.id)).orderBy(hexVisit.cell);
    return NextResponse.json({
      visits: rows.map((visit) => ({
        ...visit,
        lastVisit: visit.lastVisit.toISOString(),
        score: Number(visit.score),
        lastScore: Number(visit.lastScore),
      })),
    }, { headers: { "Cache-Control": "private, no-store" } });
  } catch {
    return serverError("Visit download failed", undefined, "Unable to download visits");
  }
}
