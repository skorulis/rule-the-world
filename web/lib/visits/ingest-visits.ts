import { and, eq, or, sql } from "drizzle-orm";
import { user } from "@/db/auth-schema";
import { hexVisit, hexVisitDay } from "@/db/schema";
import { db } from "@/lib/db";
import type { VisitBatch } from "./visit-batch";

export async function ingestVisits(userId: string, batch: VisitBatch) {
  return db.transaction(async (tx) => {
    const locked = await tx.select({ id: user.id }).from(user).where(eq(user.id, userId)).for("update");
    if (!locked.length) throw new Error("Visit owner no longer exists");

    await tx.insert(hexVisit).values(batch.cells.map(({ cell, lastVisit }) => ({ userId, cell, lastVisit })))
      .onConflictDoNothing();
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

    const visits = [];
    for (const { cell, lastVisit } of batch.cells) {
      const differences = updated.filter((row) => row.cell === cell).map((row) =>
        sql`(${row.score}::numeric - ${previousScores.get(`${cell}/${row.day}`) ?? "0"}::numeric)`);
      const latest = sql`greatest(${hexVisit.lastVisit}, ${lastVisit.toISOString()}::timestamptz)`;
      const [visit] = await tx.update(hexVisit).set({
        score: sql`${hexVisit.score} + ${sql.join(differences, sql` + `)}`,
        lastVisit: latest,
        lastScore: sql`(select ${hexVisitDay.score} from ${hexVisitDay}
          where ${hexVisitDay.userId} = ${userId} and ${hexVisitDay.cell} = ${cell}
          and ${hexVisitDay.day} = (${latest} at time zone 'UTC')::date)`,
      }).where(and(eq(hexVisit.userId, userId), eq(hexVisit.cell, cell))).returning();
      visits.push({
        cell: visit.cell,
        lastVisit: visit.lastVisit.toISOString(),
        score: Number(visit.score),
        lastScore: Number(visit.lastScore),
      });
    }
    return { acceptedIds: batch.acceptedIds, visits };
  });
}
