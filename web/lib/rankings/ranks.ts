import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export interface RankDefinition {
  number: number;
  name: string;
  femaleName?: string;
  description: string;
  minOwnership: number;
  minVisits: number;
  maxQuantity?: number;
  maxPercentage?: number;
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
      !isOptional(rank.femaleName, (value) => typeof value === "string") ||
      !isCount(rank.minOwnership) || !isCount(rank.minVisits) ||
      !isOptional(rank.maxQuantity, isCount) ||
      !isOptional(rank.maxPercentage, (value) => typeof value === "number" && value >= 0 && value <= 100) ||
      (rank.maxQuantity !== undefined && rank.maxPercentage !== undefined)
    ) {
      throw new Error(`Invalid rank definition: ${JSON.stringify(entry)}`);
    }
    return rank as RankDefinition;
  });
}

const definitions = JSON.parse(readFileSync(definitionsPath(), "utf8")) as { country?: unknown };

export const countryRanks: RankDefinition[] = parseRanks(definitions.country);
