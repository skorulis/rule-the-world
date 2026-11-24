import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { rarities, type Rarity } from "./rarity";

export interface LootBoxDefinition {
  id: number;
  name: string;
  cost: number;
  rarity: Rarity;
}

function definitionsPath(): string {
  const candidates = [
    ...(import.meta.url ? [path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../data/lootboxes.json")] : []),
    path.resolve(process.cwd(), "data/lootboxes.json"),
    path.resolve(process.cwd(), "../data/lootboxes.json"),
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

export function parseLootBoxDefinitions(raw: unknown): LootBoxDefinition[] {
  if (!Array.isArray(raw)) throw new Error("lootboxes.json must be an array");
  const seen = new Set<number>();
  return raw.map((entry) => {
    const def = entry as Partial<LootBoxDefinition>;
    if (
      !Number.isSafeInteger(def.id) || (def.id as number) <= 0 ||
      typeof def.name !== "string" || def.name.trim() === "" ||
      !Number.isSafeInteger(def.cost) || (def.cost as number) <= 0 ||
      !rarities.includes(def.rarity as Rarity)
    ) {
      throw new Error(`Invalid loot box definition: ${JSON.stringify(entry)}`);
    }
    if (!seen.add(def.id as number)) {
      throw new Error(`Duplicate loot box id: ${def.id}`);
    }
    return def as LootBoxDefinition;
  });
}

export const lootBoxDefinitions: LootBoxDefinition[] = parseLootBoxDefinitions(
  JSON.parse(readFileSync(definitionsPath(), "utf8")),
);

const byId = new Map(lootBoxDefinitions.map((def) => [def.id, def]));

export function lootBoxDefinition(id: number): LootBoxDefinition | undefined {
  return byId.get(id);
}
