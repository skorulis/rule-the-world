import { and, eq, inArray, max, ne, sql } from "drizzle-orm";
import { gridDisk } from "h3-js";
import { user } from "@/db/auth-schema";
import { hexVisit } from "@/db/schema";
import { db } from "@/lib/db";
import { getHexInfo, type HexInfoResult } from "@/lib/visits/hex-info";
import type { PowerUpDefinition } from "./powerups";

export const maxTargetRadius = 50;

export class ConsumePowerUpError extends Error {
  constructor(message: string, readonly status = 400) {
    super(message);
  }
}

export type ConsumePowerUpResult = {
  powerups: Record<string, number>;
  visits: HexInfoResult[];
};

/**
 * Applies a power-up for `userId`, targeted at the hex containing `cell` or the
 * nearest visited hex expanding outward. Consumes one unit of the power-up and
 * returns the updated inventory plus info for every changed hex.
 */
export async function consumePowerUp(
  userId: string,
  definition: PowerUpDefinition,
  cell: bigint,
): Promise<ConsumePowerUpResult> {
  return db.transaction(async (tx) => {
    const [locked] = await tx.select({ id: user.id, powerups: user.powerups })
      .from(user).where(eq(user.id, userId)).for("update");
    if (!locked) throw new Error("Power-up owner no longer exists");

    const key = String(definition.id);
    const inventory = locked.powerups ?? {};
    const count = inventory[key] ?? 0;
    if (count < 1) throw new ConsumePowerUpError("Power-up not in inventory");

    const center = cell.toString(16);
    let target: typeof hexVisit.$inferSelect | undefined;
    let previous = new Set<string>();
    for (let radius = 0; radius <= maxTargetRadius && !target; radius++) {
      const disk = new Set(gridDisk(center, radius));
      const ring = [...disk].filter((entry) => !previous.has(entry)).map((entry) => BigInt(`0x${entry}`));
      previous = disk;
      if (!ring.length) continue;
      if (definition.type === "exploration") {
        const claimed = new Set((await tx.select({ cell: hexVisit.cell }).from(hexVisit)
          .where(and(eq(hexVisit.userId, userId), inArray(hexVisit.cell, ring))))
          .map(({ cell }) => cell));
        const unvisited = ring.filter((entry) => !claimed.has(entry)).sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
        for (const candidate of unvisited) {
          const [inserted] = await tx.insert(hexVisit).values({
            userId,
            cell: candidate,
            lastVisit: new Date(0),
            score: String(definition.bonus),
          }).onConflictDoNothing().returning();
          if (inserted) {
            target = inserted;
            break;
          }
        }
      } else if (definition.type === "attack") {
        const [visits, rivals] = await Promise.all([
          tx.select().from(hexVisit)
            .where(and(eq(hexVisit.userId, userId), inArray(hexVisit.cell, ring))),
          tx.select({ cell: hexVisit.cell, rivalScore: max(hexVisit.score) }).from(hexVisit)
            .where(and(ne(hexVisit.userId, userId), inArray(hexVisit.cell, ring)))
            .groupBy(hexVisit.cell).orderBy(hexVisit.cell),
        ]);
        const scores = new Map(visits.map((visit) => [visit.cell, Number(visit.score)]));
        const rival = rivals.find(({ cell, rivalScore }) => scores.has(cell) && Number(rivalScore ?? 0) > scores.get(cell)!);
        target = rival && visits.find((visit) => visit.cell === rival.cell);
      } else if (definition.type === "fortification") {
        const [visits, rivals] = await Promise.all([
          tx.select().from(hexVisit)
            .where(and(eq(hexVisit.userId, userId), inArray(hexVisit.cell, ring)))
            .orderBy(hexVisit.cell),
          tx.select({ cell: hexVisit.cell, rivalScore: max(hexVisit.score) }).from(hexVisit)
            .where(and(ne(hexVisit.userId, userId), inArray(hexVisit.cell, ring)))
            .groupBy(hexVisit.cell),
        ]);
        const rivalScores = new Map(rivals.map(({ cell, rivalScore }) => [cell, Number(rivalScore ?? 0)]));
        target = visits.find((visit) => Number(visit.score) > (rivalScores.get(visit.cell) ?? 0));
      } else {
        const [visit] = await tx.select().from(hexVisit)
          .where(and(eq(hexVisit.userId, userId), inArray(hexVisit.cell, ring)))
          .orderBy(hexVisit.cell).limit(1);
        target = visit;
      }
    }
    if (!target) {
      const errors: Record<PowerUpDefinition["type"], string> = {
        revisit: "No visited hex in range",
        exploration: "No unvisited hex in range",
        fortification: "No owned hex in range",
        attack: "No squares in range where you already have a score and someone else owns it. Your Attack power-up was not consumed.",
      };
      throw new ConsumePowerUpError(errors[definition.type] ?? "No target hex in range", 404);
    }

    switch (definition.type) {
      case "revisit":
      case "fortification":
      case "attack":
        await tx.update(hexVisit)
          .set({ score: sql`${hexVisit.score} + ${definition.bonus}` })
          .where(and(eq(hexVisit.userId, userId), eq(hexVisit.cell, target.cell)));
        break;
      case "exploration":
        break;
      default:
        throw new ConsumePowerUpError("Unsupported power-up");
    }

    const powerups = { ...inventory };
    if (count === 1) delete powerups[key]; else powerups[key] = count - 1;
    await tx.update(user).set({ powerups }).where(eq(user.id, userId));

    return { powerups, visits: [await getHexInfo(userId, target.cell, tx)] };
  });
}
