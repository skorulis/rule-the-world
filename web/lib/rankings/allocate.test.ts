import { describe, expect, it } from "vitest";
import { allocateRanks, type RegionPlayer } from "./allocate";
import { countryRanks, type RankDefinition } from "./ranks";

const rank = (number: number, overrides: Partial<RankDefinition> = {}): RankDefinition => ({
  number, name: `Rank ${number}`, description: "", minOwnership: 0, minVisits: 1, ...overrides,
});
const player = (userId: string, owned: number, visited = owned, score = 0): RegionPlayer => ({ userId, owned, visited, score });

describe("allocateRanks", () => {
  it("cascades players to the next rank when a quantity cap is full", () => {
    const ranks = [rank(1, { minOwnership: 10, maxQuantity: 1 }), rank(2, { minOwnership: 10, maxQuantity: 1 }), rank(3)];
    const result = allocateRanks([player("b", 11), player("a", 20), player("c", 12)], ranks);
    expect(Object.fromEntries(result)).toEqual({ a: 1, c: 2, b: 3 });
  });

  it("gives percentage caps at least one slot and floors larger counts", () => {
    const ranks = [rank(1, { minOwnership: 1, maxPercentage: 10 }), rank(2)];
    const few = allocateRanks([player("a", 5), player("b", 4)], ranks);
    expect(Object.fromEntries(few)).toEqual({ a: 1, b: 2 });

    const many = allocateRanks(Array.from({ length: 29 }, (_, i) => player(`p${String(i).padStart(2, "0")}`, 100 - i)), ranks);
    expect([...many.values()].filter((value) => value === 1)).toHaveLength(2);
  });

  it("breaks ties by visits, then score, then user id", () => {
    const ranks = [rank(1, { maxQuantity: 1 }), rank(2, { maxQuantity: 1 }), rank(3, { maxQuantity: 1 }), rank(4)];
    const result = allocateRanks([
      player("d", 5, 6, 1), player("c", 5, 6, 1), player("b", 5, 6, 2), player("a", 5, 7, 0),
    ], ranks);
    expect(Object.fromEntries(result)).toEqual({ a: 1, b: 2, c: 3, d: 4 });
  });

  it("drops a player whose visits fall short of a rank's minimum", () => {
    const ranks = [rank(1, { minOwnership: 2, minVisits: 10 }), rank(2, { minOwnership: 2, minVisits: 2 })];
    expect(allocateRanks([player("a", 5, 5)], ranks).get("a")).toBe(2);
  });

  it("skips players without visits in the region", () => {
    expect(allocateRanks([player("a", 0, 0)], [rank(1)]).size).toBe(0);
  });

  it("gives every visitor at least the lowest country rank", () => {
    const players = Array.from({ length: 50 }, (_, i) => player(`p${i}`, i % 3, 1 + (i % 3)));
    const result = allocateRanks(players, countryRanks);
    expect(result.size).toBe(50);
    const lowest = countryRanks[countryRanks.length - 1].number;
    for (const value of result.values()) expect(value).toBeLessThanOrEqual(lowest);
  });

  it("assigns the top country rank to a single qualifying player", () => {
    const result = allocateRanks([player("king", 1500, 1500), player("rival", 1200, 1200)], countryRanks);
    expect(result.get("king")).toBe(1);
    expect(result.get("rival")).toBe(2);
  });
});
