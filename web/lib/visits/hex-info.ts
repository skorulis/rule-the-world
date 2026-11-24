import { and, eq, inArray, sql, sum } from "drizzle-orm";
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

/** Shared projection for a single hex, matching GET /api/hex-visits/info. */
export async function getHexInfo(
  userId: string,
  cell: bigint,
  executor: Pick<typeof db, "select"> = db,
): Promise<HexInfoResult> {
  const infos = await getHexInfos(userId, [cell], executor);
  return infos.get(cell) ?? { totals: null, userVisit: null };
}

/** Shared projection for many hexes at once, matching GET /api/hex-visits/info. */
export async function getHexInfos(
  userId: string,
  cells: bigint[],
  executor: Pick<typeof db, "select"> = db,
): Promise<Map<bigint, HexInfoResult>> {
  const [totalRows, visitRows] = await Promise.all([
    executor.select({
      cell: hexVisit.cell,
      totalVisits: sum(hexVisit.total),
      rivalScore: sql<string | null>`max(${hexVisit.score}) filter (where ${hexVisit.userId} <> ${userId})`,
    }).from(hexVisit)
      .where(inArray(hexVisit.cell, cells))
      .groupBy(hexVisit.cell),
    executor.select({
      cell: hexVisit.cell,
      total: hexVisit.total,
      lastVisit: hexVisit.lastVisit,
      score: hexVisit.score,
      lastScore: hexVisit.lastScore,
    }).from(hexVisit)
      .where(and(inArray(hexVisit.cell, cells), eq(hexVisit.userId, userId))),
  ]);

  const totals = new Map(totalRows.map((row) => [row.cell, row]));
  const visits = new Map(visitRows.map((row) => [row.cell, row]));
  return new Map(cells.map((cell) => {
    const total = totals.get(cell);
    const visit = visits.get(cell);
    return [cell, {
      totals: total?.totalVisits == null
        ? null
        : {
            totalVisits: Number(total.totalVisits),
            rivalScore: Number(total.rivalScore ?? 0),
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
    }];
  }));
}
