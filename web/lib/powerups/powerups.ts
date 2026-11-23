import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { rarities, type Rarity } from "../rarity";

export const powerUpTypes = ["revisit", "exploration", "fortification"] as const;
export type PowerUpType = (typeof powerUpTypes)[number];

export interface PowerUpDefinition {
  id: number;
  type: PowerUpType;
  rarity: Rarity;
  bonus: number;
  description: string;
}

function definitionsPath(): string {
  const candidates = [
    ...(import.meta.url ? [path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../../data/powerups.json")] : []),
    path.resolve(process.cwd(), "data/powerups.json"),
    path.resolve(process.cwd(), "../data/powerups.json"),
  ];
  return candidates.find((candidate) => {
    try {
      readFileSync(candidate);
      return true;
    } catch {
      return false;
    }
  }) ?? candidates[0];
}

function parseDefinitions(raw: unknown): PowerUpDefinition[] {
  if (!Array.isArray(raw)) throw new Error("powerups.json must be an array");
  const seen = new Set<number>();
  return raw.map((entry) => {
    const def = entry as Partial<PowerUpDefinition>;
    if (
      !Number.isSafeInteger(def.id) || (def.id as number) <= 0 ||
      !powerUpTypes.includes(def.type as PowerUpType) ||
      !rarities.includes(def.rarity as Rarity) ||
      !Number.isSafeInteger(def.bonus) ||
      typeof def.description !== "string"
    ) {
      throw new Error(`Invalid power-up definition: ${JSON.stringify(entry)}`);
    }
    if (!seen.add(def.id as number)) {
      throw new Error(`Duplicate power-up id: ${def.id}`);
    }
    return def as PowerUpDefinition;
  });
}

export const powerUpDefinitions: PowerUpDefinition[] = parseDefinitions(
  JSON.parse(readFileSync(definitionsPath(), "utf8")),
);

const byId = new Map(powerUpDefinitions.map((def) => [def.id, def]));

export function powerUpDefinition(id: number): PowerUpDefinition | undefined {
  return byId.get(id);
}

/** Uniform random pick, optionally limited to one rarity — used by the grant endpoints. */
export function randomPowerUp(
  random: () => number = Math.random,
  rarity?: Rarity,
): PowerUpDefinition {
  const pool = rarity ? powerUpDefinitions.filter((def) => def.rarity === rarity) : powerUpDefinitions;
  if (pool.length === 0) throw new Error(`No power-up definitions${rarity ? ` for rarity ${rarity}` : ""}`);
  return pool[Math.floor(random() * pool.length)];
}
