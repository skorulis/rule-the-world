import { describe, expect, it } from "vitest";
import { countryRanks, globalRanks, suburbRanks, parseRanks } from "./ranks";

const valid = { number: 1, name: "King", rarity: "mythic", description: "Ruler", minOwnership: 10, minVisits: 1, maxQuantity: 1 };

describe("rank definitions", () => {
  it("loads the country ranks in ascending order", () => {
    expect(countryRanks.length).toBeGreaterThan(0);
    const numbers = countryRanks.map((rank) => rank.number);
    expect(numbers).toEqual([...numbers].sort((a, b) => a - b));
    expect(new Set(numbers).size).toBe(numbers.length);
  });

  it("loads the suburb ranks in ascending order", () => {
    expect(suburbRanks.map((rank) => [rank.number, rank.name])).toEqual([
      [1, "Mayor"],
      [2, "Deputy Mayor"],
      [3, "Councillor"],
      [4, "Steward"],
      [5, "Local"],
      [6, "Visitor"],
    ]);
  });

  it("reserves mythic for kings", () => {
    expect(countryRanks.filter((rank) => rank.rarity === "mythic").map((rank) => rank.name)).toEqual(["King"]);
    expect(countryRanks.find((rank) => rank.name === "Prince")?.rarity).toBe("legendary");
    expect(suburbRanks.some((rank) => rank.rarity === "mythic")).toBe(false);
  });

  it("loads twenty global ranks with icons and increasing eligibility requirements", () => {
    expect(globalRanks.map((rank) => rank.number)).toEqual(Array.from({ length: 20 }, (_, i) => i + 1));
    expect(globalRanks[0]).toMatchObject({ name: "Emperor", femaleName: "Empress", maxQuantity: 1 });
    for (const [index, rank] of globalRanks.entries()) {
      expect(rank.icon).toBe(`Rank${rank.name.replaceAll(" ", "")}`);
      if (index > 0) {
        expect(rank.minOwnership).toBeLessThanOrEqual(globalRanks[index - 1].minOwnership);
        expect(rank.minVisits).toBeLessThanOrEqual(globalRanks[index - 1].minVisits);
      }
    }
  });

  it("accepts a valid definition", () => {
    expect(parseRanks([valid])).toEqual([valid]);
  });

  it.each([
    ["not an array", {}],
    ["empty", []],
    ["non-positive number", [{ ...valid, number: 0 }]],
    ["duplicate number", [valid, valid]],
    ["descending numbers", [{ ...valid, number: 2 }, valid]],
    ["negative minimum", [{ ...valid, minOwnership: -1 }]],
    ["fractional minimum", [{ ...valid, minVisits: 1.5 }]],
    ["missing name", [{ ...valid, name: undefined }]],
    ["missing rarity", [{ ...valid, rarity: undefined }]],
    ["unknown rarity", [{ ...valid, rarity: "unknown" }]],
    ["both caps", [{ ...valid, maxPercentage: 5 }]],
    ["percentage over 100", [{ ...valid, maxQuantity: undefined, maxPercentage: 101 }]],
  ])("rejects %s", (_, raw) => {
    expect(() => parseRanks(raw)).toThrow();
  });
});
