import { describe, expect, it } from "vitest";
import {
  powerUpDefinition,
  powerUpDefinitions,
  powerUpRarities,
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
      expect(powerUpRarities).toContain(def.rarity);
      expect(Number.isInteger(def.bonus)).toBe(true);
      expect(def.name.trim()).not.toBe("");
      expect(def.description).toContain("{bonus}");
    }
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
});
