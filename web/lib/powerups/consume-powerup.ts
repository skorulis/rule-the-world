import { eq, sql } from "drizzle-orm";
import { user } from "@/db/auth-schema";
import { hexVisit } from "@/db/schema";
import { db } from "@/lib/db";
import { getHexInfos, type HexInfoResult } from "@/lib/visits/hex-info";
import type { PowerUpDefinition } from "./powerups";

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
 * Applies a power-up for `userId` to client-selected `cells`. Clients are
 * trusted to pick viable targets from their visible map window; the server
 * boosts whatever cells it receives (clamped to the definition's square
 * count) so out-of-date client data never fails the consume. Consumes one
 * unit of the power-up and returns the updated inventory plus info for
 * every changed hex.
 */
export async function consumePowerUp(
  userId: string,
  definition: PowerUpDefinition,
  cells: bigint[],
): Promise<ConsumePowerUpResult> {
  const targets = [...new Set(cells)].slice(0, definition.squares);
  if (!targets.length) throw new ConsumePowerUpError("No target hexes supplied");
  return db.transaction(async (tx) => {
    const [locked] = await tx.select({ id: user.id, powerups: user.powerups })
      .from(user).where(eq(user.id, userId)).for("update");
    if (!locked) throw new Error("Power-up owner no longer exists");

    const key = String(definition.id);
    const inventory = locked.powerups ?? {};
    const count = inventory[key] ?? 0;
    if (count < 1) throw new ConsumePowerUpError("Power-up not in inventory");

    await tx.insert(hexVisit)
      .values(targets.map((cell) => ({
        userId,
        cell,
        lastVisit: new Date(0),
        score: String(definition.bonus),
      })))
      .onConflictDoUpdate({
        target: [hexVisit.userId, hexVisit.cell],
        set: { score: sql`${hexVisit.score} + ${definition.bonus}` },
      });

    const powerups = { ...inventory };
    if (count === 1) delete powerups[key]; else powerups[key] = count - 1;
    await tx.update(user).set({ powerups }).where(eq(user.id, userId));

    const infos = await getHexInfos(userId, targets, tx);
    return { powerups, visits: targets.map((cell) => infos.get(cell) ?? {
      totals: null, regions: null, userVisit: null,
    }) };
  });
}
