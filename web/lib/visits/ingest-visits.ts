import { cellToLatLng } from "h3-js";
import { and, eq, inArray, or, sql } from "drizzle-orm";
import { user } from "@/db/auth-schema";
import { hexRegion, hexVisit, hexVisitDay, hexVisitUpload, noRegion, regionType, type RegionType } from "@/db/schema";
import { db } from "@/lib/db";
import { regionIdForPoint, stateIdForPoint } from "@/lib/regions/country-regions";
import type { VisitBatch } from "./visit-batch";

export async function ingestVisits(userId: string, batch: VisitBatch) {
  return db.transaction(async (tx) => {
    const locked = await tx.select({ id: user.id }).from(user).where(eq(user.id, userId)).for("update");
    if (!locked.length) throw new Error("Visit owner no longer exists");

    await tx.insert(hexVisit).values(batch.cells.map(({ cell, lastVisit }) => ({ userId, cell, lastVisit })))
      .onConflictDoNothing();

    const known = await tx.select({
      cell: hexRegion.cell, region: hexRegion.region, regionType: hexRegion.regionType,
    }).from(hexRegion).where(inArray(hexRegion.cell, batch.cells.map(({ cell }) => cell)));
    const countries = new Map<bigint, bigint>();
    const knownStates = new Set<bigint>();
    for (const row of known) {
      if (row.regionType === regionType.state) knownStates.add(row.cell);
      else countries.set(row.cell, row.region);
    }
    const rows: { cell: bigint; region: bigint; regionType: RegionType }[] = [];
    for (const cell of new Set(batch.cells.map(({ cell }) => cell))) {
      const [latitude, longitude] = cellToLatLng(cell.toString(16));
      if (!countries.has(cell)) {
        const region = regionIdForPoint(latitude, longitude);
        countries.set(cell, region);
        rows.push({ cell, region, regionType: region === noRegion ? regionType.none : regionType.country });
      }
      const country = countries.get(cell) ?? noRegion;
      if (!knownStates.has(cell) && country !== noRegion) {
        const state = stateIdForPoint(country, latitude, longitude);
        if (state !== noRegion) rows.push({ cell, region: state, regionType: regionType.state });
      }
    }
    if (rows.length) {
      await tx.insert(hexRegion).values(rows).onConflictDoNothing();
    }
    const previous = await tx.select().from(hexVisitDay).where(and(
      eq(hexVisitDay.userId, userId),
      or(...batch.days.map(({ cell, day }) => and(eq(hexVisitDay.cell, cell), eq(hexVisitDay.day, day)))),
    ));
    const previousScores = new Map(previous.map((row) => [`${row.cell}/${row.day}`, row.score]));
    const updated = await tx.insert(hexVisitDay).values(batch.days.map((day) => ({
      ...day, userId, score: String(day.score),
    }))).onConflictDoUpdate({
      target: [hexVisitDay.userId, hexVisitDay.cell, hexVisitDay.day],
      set: { score: sql`greatest(${hexVisitDay.score}, excluded.score)` },
    }).returning();

    const uploaded = await tx.select().from(hexVisitUpload).where(and(
      eq(hexVisitUpload.userId, userId), inArray(hexVisitUpload.id, batch.acceptedIds),
    ));
    const previousUploads = new Map(uploaded.map((row) => [row.id, row]));
    const totals = new Map<bigint, number>();
    for (const entry of batch.counts) {
      const previous = previousUploads.get(entry.id);
      if (previous && previous.cell !== entry.cell) throw new Error("Upload cell cannot change");
      totals.set(entry.cell, (totals.get(entry.cell) ?? 0) + Math.max(entry.count - (previous?.count ?? 0), 0));
    }
    await tx.insert(hexVisitUpload).values(batch.counts.map((entry) => ({ ...entry, userId })))
      .onConflictDoUpdate({
        target: [hexVisitUpload.userId, hexVisitUpload.id],
        set: { count: sql`greatest(${hexVisitUpload.count}, excluded.count)` },
      });

    const visits = [];
    for (const { cell, lastVisit } of batch.cells) {
      const differences = updated.filter((row) => row.cell === cell).map((row) =>
        sql`(${row.score}::numeric - ${previousScores.get(`${cell}/${row.day}`) ?? "0"}::numeric)`);
      const latest = sql`greatest(${hexVisit.lastVisit}, ${lastVisit.toISOString()}::timestamptz)`;
      const [visit] = await tx.update(hexVisit).set({
        total: sql`${hexVisit.total} + ${totals.get(cell) ?? 0}`,
        score: sql`${hexVisit.score} + ${sql.join(differences, sql` + `)}`,
        lastVisit: latest,
        lastScore: sql`(select ${hexVisitDay.score} from ${hexVisitDay}
          where ${hexVisitDay.userId} = ${userId} and ${hexVisitDay.cell} = ${cell}
          and ${hexVisitDay.day} = (${latest} at time zone 'UTC')::date)`,
      }).where(and(eq(hexVisit.userId, userId), eq(hexVisit.cell, cell))).returning();
      visits.push({
        cell: visit.cell.toString(16),
        total: visit.total,
        lastVisit: visit.lastVisit.toISOString(),
        score: Number(visit.score),
        lastScore: Number(visit.lastScore),
      });
    }
    return { acceptedIds: batch.acceptedIds, visits };
  });
}
