import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { rarities, type Rarity } from "../rarity";

export interface RankDefinition {
  number: number;
  name: string;
  rarity: Rarity;
  femaleName?: string;
  description: string;
  icon?: string;
  minOwnership: number;
  minVisits: number;
  maxQuantity?: number;
  maxPercentage?: number;
  stipend?: number;
}

function definitionsPath(): string {
  const candidates = [
    ...(import.meta.url ? [path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../../data/ranks.json")] : []),
    path.resolve(process.cwd(), "data/ranks.json"),
    path.resolve(process.cwd(), "../data/ranks.json"),
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

const isCount = (value: unknown) => Number.isSafeInteger(value) && (value as number) >= 0;
const isOptional = (value: unknown, valid: (value: unknown) => boolean) => value === undefined || valid(value);

export function parseRanks(raw: unknown): RankDefinition[] {
  if (!Array.isArray(raw) || raw.length === 0) throw new Error("Ranks must be a non-empty array");
  return raw.map((entry, index) => {
    const rank = entry as Partial<RankDefinition>;
    if (
      !Number.isSafeInteger(rank.number) || (rank.number as number) <= 0 ||
      (index > 0 && (rank.number as number) <= (raw[index - 1] as RankDefinition).number) ||
      typeof rank.name !== "string" || typeof rank.description !== "string" ||
      !rarities.includes(rank.rarity as Rarity) ||
      !isOptional(rank.femaleName, (value) => typeof value === "string") ||
      !isOptional(rank.icon, (value) => typeof value === "string") ||
      !isCount(rank.minOwnership) || !isCount(rank.minVisits) ||
      !isOptional(rank.maxQuantity, isCount) ||
      !isOptional(rank.stipend, isCount) ||
      !isOptional(rank.maxPercentage, (value) => typeof value === "number" && value >= 0 && value <= 100) ||
      (rank.maxQuantity !== undefined && rank.maxPercentage !== undefined)
    ) {
      throw new Error(`Invalid rank definition: ${JSON.stringify(entry)}`);
    }
    return rank as RankDefinition;
  });
}

const definitions = JSON.parse(readFileSync(definitionsPath(), "utf8")) as { global?: unknown; country?: unknown; suburb?: unknown };

export const globalRanks: RankDefinition[] = parseRanks(definitions.global);

export const countryRanks: RankDefinition[] = parseRanks(definitions.country);
export const suburbRanks: RankDefinition[] = parseRanks(definitions.suburb);
