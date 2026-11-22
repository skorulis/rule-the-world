import { and, eq, inArray, or, sql } from "drizzle-orm";
import { user } from "@/db/auth-schema";
import { hexDetails, hexVisit, hexVisitDay, hexVisitUpload } from "@/db/schema";
import { db } from "@/lib/db";
import { calculateHexDetails } from "@/lib/regions/hex-details";
import type { VisitBatch } from "./visit-batch";

export async function ingestVisits(userId: string, batch: VisitBatch) {
  return db.transaction(async (tx) => {
    const locked = await tx.select({ id: user.id }).from(user).where(eq(user.id, userId)).for("update");
    if (!locked.length) throw new Error("Visit owner no longer exists");

    await tx.insert(hexVisit).values(batch.cells.map(({ cell, lastVisit }) => ({ userId, cell, lastVisit })))
      .onConflictDoNothing();

    const cells = [...new Set(batch.cells.map(({ cell }) => cell))];
    const known = await tx.select({ cell: hexDetails.cell }).from(hexDetails)
      .where(inArray(hexDetails.cell, cells));
    const classified = new Set(known.map(({ cell }) => cell));
    const rows: (typeof hexDetails.$inferInsert)[] = [];
    for (const cell of cells) {
      if (classified.has(cell)) continue;
      rows.push(calculateHexDetails(cell));
    }
    if (rows.length) {
      await tx.insert(hexDetails).values(rows).onConflictDoNothing();
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
