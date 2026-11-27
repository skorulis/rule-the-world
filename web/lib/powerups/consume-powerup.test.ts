import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("@/lib/db", () => ({ db: { transaction: vi.fn() } }));
vi.mock("@/lib/visits/hex-info", () => ({ getHexInfos: vi.fn() }));

import { user } from "@/db/auth-schema";
import { hexVisit } from "@/db/schema";
import { db } from "@/lib/db";
import { getHexInfos } from "@/lib/visits/hex-info";
import { consumePowerUp } from "./consume-powerup";
import { powerUpDefinition } from "./powerups";

const cell = BigInt("0x8a2830828767fff");
const otherCell = cell + BigInt(1);
const attack = powerUpDefinition(1)!;
const changed = { totals: { totalVisits: 1, rivalScore: 4 }, regions: null, userVisit: null };

function transaction(powerups: Record<string, number> = { "1": 2 }) {
  const where = vi.fn().mockResolvedValue(undefined);
  const set = vi.fn().mockReturnValue({ where });
  const onConflictDoUpdate = vi.fn().mockResolvedValue(undefined);
  const values = vi.fn().mockReturnValue({ onConflictDoUpdate });
  const tx = {
    select: vi.fn(() => ({
      from: vi.fn().mockReturnThis(),
      where: vi.fn().mockReturnThis(),
      for: vi.fn().mockReturnThis(),
      then: (resolve: (value: unknown[]) => unknown) =>
        Promise.resolve([{ id: "u1", powerups }]).then(resolve),
    })),
    insert: vi.fn().mockReturnValue({ values }),
    update: vi.fn().mockReturnValue({ set }),
  };
  vi.mocked(db.transaction).mockImplementation(async (callback) => callback(tx as never));
  return { tx, set, values, onConflictDoUpdate };
}

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(getHexInfos).mockResolvedValue(new Map([[cell, changed]]));
});

describe("consumePowerUp", () => {
  it("upserts the bonus onto every supplied cell and decrements inventory", async () => {
    const { tx, set, values, onConflictDoUpdate } = transaction();
    const result = await consumePowerUp("u1", attack, [cell, otherCell]);
    expect(tx.insert).toHaveBeenCalledWith(hexVisit);
    expect(values).toHaveBeenCalledWith([
      { userId: "u1", cell, lastVisit: new Date(0), score: "1" },
      { userId: "u1", cell: otherCell, lastVisit: new Date(0), score: "1" },
    ]);
    expect(onConflictDoUpdate).toHaveBeenCalledWith({
      target: [hexVisit.userId, hexVisit.cell],
      set: { score: expect.anything() },
    });
    expect(tx.update).toHaveBeenCalledWith(user);
    expect(set).toHaveBeenCalledWith({ powerups: { "1": 1 } });
    expect(getHexInfos).toHaveBeenCalledWith("u1", [cell, otherCell], tx);
    expect(result).toEqual({ powerups: { "1": 1 }, visits: [changed, {
      totals: null, regions: null, userVisit: null,
    }] });
  });

  it("removes the inventory entry when the last unit is consumed", async () => {
    const { set } = transaction({ "1": 1 });
    const result = await consumePowerUp("u1", attack, [cell]);
    expect(set).toHaveBeenCalledWith({ powerups: {} });
    expect(result.powerups).toEqual({});
  });

  it("dedupes cells and clamps to the definition's square count", async () => {
    const { values } = transaction({ "1": 1 });
    const extras = Array.from({ length: 5 }, (_, index) => cell + BigInt(index + 1));
    await consumePowerUp("u1", attack, [cell, cell, ...extras]);
    const inserted = vi.mocked(values).mock.calls[0][0] as { cell: bigint }[];
    expect(inserted.map((row) => row.cell)).toEqual([cell, ...extras.slice(0, 2)]);
    expect(getHexInfos).toHaveBeenCalledWith("u1", [cell, ...extras.slice(0, 2)], expect.anything());
  });

  it("rejects an empty cell list before touching the database", async () => {
    await expect(consumePowerUp("u1", attack, [])).rejects.toMatchObject({
      status: 400, message: "No target hexes supplied",
    });
    expect(db.transaction).not.toHaveBeenCalled();
  });

  it("does not consume when the power-up is not in inventory", async () => {
    const { tx } = transaction({ "2": 3 });
    await expect(consumePowerUp("u1", attack, [cell])).rejects.toMatchObject({
      status: 400, message: "Power-up not in inventory",
    });
    expect(tx.insert).not.toHaveBeenCalled();
    expect(tx.update).not.toHaveBeenCalled();
    expect(getHexInfos).not.toHaveBeenCalled();
  });
});
