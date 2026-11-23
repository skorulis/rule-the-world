import { and, eq, max, ne, sum } from "drizzle-orm";
import { hexVisit } from "@/db/schema";
import { db } from "@/lib/db";

export type HexInfoResult = {
  totals: { totalVisits: number; rivalScore: number } | null;
  userVisit: {
    cell: string;
    total: number;
    lastVisit: string;
    score: number;
    lastScore: number;
  } | null;
};

/** Shared projection for a single hex, matching GET /api/hex-visits/[cell]. */
export async function getHexInfo(
  userId: string,
  cell: bigint,
  executor: Pick<typeof db, "select"> = db,
): Promise<HexInfoResult> {
  const [[totals], [rival], [visit]] = await Promise.all([
    executor.select({ totalVisits: sum(hexVisit.total) }).from(hexVisit)
      .where(eq(hexVisit.cell, cell)),
    executor.select({ rivalScore: max(hexVisit.score) }).from(hexVisit)
      .where(and(eq(hexVisit.cell, cell), ne(hexVisit.userId, userId))),
    executor.select({
      cell: hexVisit.cell,
      total: hexVisit.total,
      lastVisit: hexVisit.lastVisit,
      score: hexVisit.score,
      lastScore: hexVisit.lastScore,
    }).from(hexVisit)
      .where(and(eq(hexVisit.cell, cell), eq(hexVisit.userId, userId))),
  ]);

  return {
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
  };
}
