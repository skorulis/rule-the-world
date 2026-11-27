import { describe, expect, it } from "vitest";
import { rarities } from "../rarity";
import {
  powerUpDefinition,
  powerUpDefinitions,
  powerUpTypes,
  randomPowerUp,
} from "./powerups";

describe("powerup definitions", () => {
  it("loads definitions with unique positive ids", () => {
    expect(powerUpDefinitions.length).toBeGreaterThan(0);
    const ids = powerUpDefinitions.map((def) => def.id);
    expect(new Set(ids).size).toBe(ids.length);
    for (const def of powerUpDefinitions) {
      expect(def.id).toBeGreaterThan(0);
      expect(powerUpTypes).toContain(def.type);
      expect(rarities).toContain(def.rarity);
      expect(Number.isInteger(def.bonus)).toBe(true);
      expect(def.squares).toBeGreaterThan(0);
      expect(def.description.trim()).not.toBe("");
      expect(def.description).toContain("{bonus}");
      expect(def.description).toContain("{squares}");
    }
  });

  it("defines each type at common and rare", () => {
    for (const type of powerUpTypes) {
      expect(powerUpDefinitions.some((def) => def.type === type && def.rarity === "common")).toBe(true);
      expect(powerUpDefinitions.some((def) => def.type === type && def.rarity === "rare")).toBe(true);
    }
  });

  it("common adds +1 to 3 squares and rare adds +2 to 5 squares", () => {
    for (const def of powerUpDefinitions) {
      expect(def).toMatchObject(def.rarity === "common"
        ? { bonus: 1, squares: 3 }
        : { bonus: 2, squares: 5 });
    }
  });

  it("includes Common and Rare Attack", () => {
    expect(powerUpDefinition(1)).toMatchObject({ type: "attack", rarity: "common", bonus: 1, squares: 3 });
    expect(powerUpDefinition(2)).toMatchObject({ type: "attack", rarity: "rare", bonus: 2, squares: 5 });
  });

  it("looks up definitions by id", () => {
    const first = powerUpDefinitions[0];
    expect(powerUpDefinition(first.id)).toEqual(first);
    expect(powerUpDefinition(-1)).toBeUndefined();
  });

  it("randomPowerUp picks uniformly from the definitions", () => {
    expect(randomPowerUp(() => 0)).toBe(powerUpDefinitions[0]);
    expect(randomPowerUp(() => 0.999)).toBe(powerUpDefinitions[powerUpDefinitions.length - 1]);
  });

  it("randomPowerUp can be limited to a single rarity", () => {
    const commons = powerUpDefinitions.filter((def) => def.rarity === "common");
    expect(commons.length).toBeGreaterThan(0);
    expect(randomPowerUp(() => 0, "common")).toBe(commons[0]);
    expect(randomPowerUp(() => 0.999, "common")).toBe(commons[commons.length - 1]);
    for (let step = 0; step < 20; step++) {
      expect(randomPowerUp(() => step / 20, "common").rarity).toBe("common");
    }
  });
});
