import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("@/lib/db", () => ({ db: { transaction: vi.fn() } }));
vi.mock("@/lib/visits/hex-info", () => ({ getHexInfo: vi.fn() }));
vi.mock("h3-js", () => ({ gridDisk: vi.fn() }));

import { gridDisk } from "h3-js";
import { user } from "@/db/auth-schema";
import { hexVisit } from "@/db/schema";
import { db } from "@/lib/db";
import { getHexInfo } from "@/lib/visits/hex-info";
import { consumePowerUp, maxTargetRadius } from "./consume-powerup";
import { powerUpDefinition } from "./powerups";

const cell = BigInt("0x8a2830828767fff");
const attack = powerUpDefinition(6)!;
const changed = { totals: { totalVisits: 1, rivalScore: 4 }, userVisit: null };

function transaction(
  visits: { cell: bigint; score: string; total?: number }[],
  rivals: { cell: bigint; rivalScore: string }[],
  powerups: Record<string, number> = { "6": 2 },
) {
  const results: unknown[][] = [[{ id: "u1", powerups }], visits, rivals];
  const where = vi.fn().mockResolvedValue(undefined);
  const set = vi.fn().mockReturnValue({ where });
  const tx = {
    select: vi.fn(() => {
      const result = results.shift() ?? [];
      const query = {
        from: vi.fn().mockReturnThis(),
        where: vi.fn().mockReturnThis(),
        for: vi.fn().mockReturnThis(),
        groupBy: vi.fn().mockReturnThis(),
        orderBy: vi.fn().mockReturnThis(),
        then: (resolve: (value: unknown[]) => unknown) => Promise.resolve(result).then(resolve),
      };
      return query;
    }),
    insert: vi.fn(),
    update: vi.fn().mockReturnValue({ set }),
  };
  vi.mocked(db.transaction).mockImplementation(async (callback) => callback(tx as never));
  return { tx, set };
}

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(gridDisk).mockImplementation(() => [cell.toString(16)]);
  vi.mocked(getHexInfo).mockResolvedValue(changed);
});

describe("Conquer consumption", () => {
  const conquer = powerUpDefinition(7)!;

  it("boosts a contested square and consumes one Rare Conquer", async () => {
    const { tx, set } = transaction([{ cell, score: "4", total: 2 }], [{ cell, rivalScore: "4" }], { "7": 2 });
    const result = await consumePowerUp("u1", conquer, cell);
    expect(tx.insert).not.toHaveBeenCalled();
    expect(tx.update).toHaveBeenNthCalledWith(1, hexVisit);
    expect(set).toHaveBeenCalledWith({ score: expect.anything() });
    expect(tx.update).toHaveBeenNthCalledWith(2, user);
    expect(set).toHaveBeenCalledWith({ powerups: { "7": 1 } });
    expect(result).toEqual({ powerups: { "7": 1 }, visits: [changed] });
    expect(getHexInfo).toHaveBeenCalledWith("u1", cell, tx);
  });

  it.each([
    { visits: [], rivals: [{ cell, rivalScore: "4" }] },
    { visits: [{ cell, score: "4", total: 2 }], rivals: [] },
    { visits: [{ cell, score: "5", total: 2 }], rivals: [{ cell, rivalScore: "4" }] },
    { visits: [{ cell, score: "3", total: 2 }], rivals: [{ cell, rivalScore: "4" }] },
    { visits: [{ cell, score: "0.5", total: 1 }], rivals: [{ cell, rivalScore: "0.5" }] },
    { visits: [{ cell, score: "4", total: 0 }], rivals: [{ cell, rivalScore: "4" }] },
  ])("preserves inventory for a non-contested square: %j", async ({ visits, rivals }) => {
    const { tx } = transaction(visits, rivals, { "7": 1 });
    await expect(consumePowerUp("u1", conquer, cell)).rejects.toMatchObject({
      status: 404,
      message: "No contested squares in range. Your Conquer power-up was not consumed.",
    });
    expect(tx.insert).not.toHaveBeenCalled();
    expect(tx.update).not.toHaveBeenCalled();
    expect(getHexInfo).not.toHaveBeenCalled();
  });
});

describe("Attack consumption", () => {
  it.each(["0", "2"])("adds to an existing score of %s on a rival-owned square", async (score) => {
    const { tx, set } = transaction([{ cell, score }], [{ cell, rivalScore: "4" }]);
    const result = await consumePowerUp("u1", attack, cell);
    expect(tx.insert).not.toHaveBeenCalled();
    expect(tx.update).toHaveBeenNthCalledWith(1, hexVisit);
    expect(set).toHaveBeenCalledWith({ score: expect.anything() });
    expect(tx.update).toHaveBeenNthCalledWith(2, user);
    expect(set).toHaveBeenCalledWith({ powerups: { "6": 1 } });
    expect(result).toEqual({ powerups: { "6": 1 }, visits: [changed] });
    expect(getHexInfo).toHaveBeenCalledWith("u1", cell, tx);
  });

  it.each([
    { visits: [], rivals: [] },
    { visits: [], rivals: [{ cell, rivalScore: "4" }] },
    { visits: [{ cell, score: "5" }], rivals: [{ cell, rivalScore: "4" }] },
    { visits: [{ cell, score: "4" }], rivals: [{ cell, rivalScore: "4" }] },
    { visits: [], rivals: [{ cell, rivalScore: "0" }] },
  ])("does not consume without an eligible target: %j", async ({ visits, rivals }) => {
    const { tx } = transaction(visits, rivals);
    await expect(consumePowerUp("u1", attack, cell)).rejects.toMatchObject({
      status: 404,
      message: "No squares in range where you already have a score and someone else owns it. Your Attack power-up was not consumed.",
    });
    expect(tx.insert).not.toHaveBeenCalled();
    expect(tx.update).not.toHaveBeenCalled();
    expect(getHexInfo).not.toHaveBeenCalled();
    expect(gridDisk).toHaveBeenLastCalledWith(cell.toString(16), maxTargetRadius);
  });
});
