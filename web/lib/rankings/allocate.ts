import type { RankDefinition } from "./ranks";

export interface RegionPlayer {
  userId: string;
  owned: number;
  visited: number;
  score: number;
}

function capacity(rank: RankDefinition, visitors: number): number {
  if (rank.maxQuantity !== undefined) return rank.maxQuantity;
  if (rank.maxPercentage !== undefined) return Math.max(1, Math.floor(rank.maxPercentage / 100 * visitors));
  return Infinity;
}

/** Greedily assigns each player the best rank they qualify for that still has free slots. */
export function allocateRanks(players: RegionPlayer[], ranks: RankDefinition[]): Map<string, number> {
  const visitors = players.filter((player) => player.visited > 0);
  const remaining = new Map(ranks.map((rank) => [rank.number, capacity(rank, visitors.length)]));
  const ordered = [...visitors].sort((a, b) =>
    b.owned - a.owned || b.visited - a.visited || b.score - a.score || (a.userId < b.userId ? -1 : a.userId > b.userId ? 1 : 0));
  const assigned = new Map<string, number>();
  for (const player of ordered) {
    const rank = ranks.find((candidate) =>
      player.owned >= candidate.minOwnership && player.visited >= candidate.minVisits &&
      (remaining.get(candidate.number) ?? 0) > 0);
    if (!rank) continue;
    remaining.set(rank.number, (remaining.get(rank.number) ?? 0) - 1);
    assigned.set(player.userId, rank.number);
  }
  return assigned;
}
