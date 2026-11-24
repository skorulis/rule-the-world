import { describe, expect, it } from "vitest";
import { lootBoxDefinition, lootBoxDefinitions, parseLootBoxDefinitions } from "./lootboxes";

describe("lootboxes.json", () => {
  it("loads definitions with unique ids and valid rarities", () => {
    expect(lootBoxDefinitions.length).toBeGreaterThan(0);
    const ids = new Set(lootBoxDefinitions.map((def) => def.id));
    expect(ids.size).toBe(lootBoxDefinitions.length);
    for (const def of lootBoxDefinitions) {
      expect(def.name.trim()).not.toBe("");
      expect(def.cost).toBeGreaterThan(0);
      expect(lootBoxDefinition(def.id)).toEqual(def);
    }
  });
});

describe("parseLootBoxDefinitions", () => {
  const valid = { id: 1, name: "Box", cost: 10, rarity: "common" };

  it("parses valid definitions", () => {
    expect(parseLootBoxDefinitions([valid])).toEqual([valid]);
  });

  it("rejects non-arrays and invalid entries", () => {
    expect(() => parseLootBoxDefinitions({})).toThrow("must be an array");
    for (const bad of [
      { ...valid, id: 0 },
      { ...valid, id: 1.5 },
      { ...valid, name: "" },
      { ...valid, cost: 0 },
      { ...valid, cost: -5 },
      { ...valid, rarity: "mythical" },
      { id: 2 },
    ]) {
      expect(() => parseLootBoxDefinitions([bad])).toThrow("Invalid loot box definition");
    }
  });

  it("rejects duplicate ids", () => {
    expect(() => parseLootBoxDefinitions([valid, { ...valid, name: "Other" }]))
      .toThrow("Duplicate loot box id: 1");
  });
});
