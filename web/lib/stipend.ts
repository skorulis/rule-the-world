import type { RegionRanking } from "@/db/auth-schema";
import { countryRanks, globalRanks, stateRanks, suburbRanks } from "./rankings/ranks";

/** Coins every player can collect daily, before title stipends. */
export const baseStipend = 10;

const definitions = { global: globalRanks, country: countryRanks, state: stateRanks, suburb: suburbRanks };

/** The total daily stipend (base + held titles) for a player's rankings. */
export function dailyStipend(rankings: RegionRanking[]): number {
  return rankings.reduce((total, ranking) => {
    const ranks = definitions[ranking.type];
    const rank = ranks?.find((candidate) => candidate.number === ranking.number);
    return total + (rank?.stipend ?? 0);
  }, baseStipend);
}
