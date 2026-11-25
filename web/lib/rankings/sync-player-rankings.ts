import { sql } from "drizzle-orm";
import type { RegionRanking } from "@/db/auth-schema";
import { playerRanking } from "@/db/schema";
import type { db } from "@/lib/db";
import { loadRegionAggregates, type RankingRegionType } from "./aggregates";
import { countryRanks, globalRanks, suburbRanks, type RankDefinition } from "./ranks";

const definitions: Record<RankingRegionType, RankDefinition[]> = {
  global: globalRanks,
  country: countryRanks,
  suburb: suburbRanks,
};

/** Best rank with no player limit the totals qualify for, or null. Rank lists are best-first. */
function bestUnlimitedRank(type: RankingRegionType, visited: number, owned: number): number | null {
  const rank = definitions[type].find((candidate) =>
    candidate.maxQuantity === undefined && candidate.maxPercentage === undefined &&
    owned >= candidate.minOwnership && visited >= candidate.minVisits);
  return rank?.number ?? null;
}

/**
 * Refreshes one player's `player_ranking` rows during a visit sync: updates visit/owned counts
 * and upgrades to newly qualified unlimited ranks. Limited ranks and demotions are left to the
 * full `calculateRankings` run. Returns the rows that changed so the sync can report them.
 */
export async function syncPlayerRankings(
  userId: string,
  executor: Parameters<Parameters<typeof db.transaction>[0]>[0],
): Promise<RegionRanking[]> {
  await executor.execute(sql`select pg_advisory_xact_lock_shared(hashtext('calculate_rankings'))`);

  const aggregates = await loadRegionAggregates(executor, userId);
  const existing = await executor.execute<{
      region_id: string;
      region_type: RankingRegionType;
      visit_count: number;
      owned_count: number;
      rank_number: number;
    }>(sql`
      select ${playerRanking.regionId} as region_id, ${playerRanking.regionType} as region_type,
        ${playerRanking.visitCount} as visit_count, ${playerRanking.ownedCount} as owned_count,
        ${playerRanking.rankNumber} as rank_number
      from ${playerRanking}
      where ${playerRanking.userId} = ${userId}
    `);
  const previous = new Map(
    existing.map((row) => [`${row.region_type}:${row.region_id}`, row]),
  );

  const changed: RegionRanking[] = [];
  const writes: {
    user_id: string;
    region_id: number;
    region_type: RankingRegionType;
    visit_count: number;
    owned_count: number;
    rank_number: number;
  }[] = [];
  for (const aggregate of aggregates) {
    const visited = Number(aggregate.visited);
    if (visited <= 0) continue;
    const regionId = Number(aggregate.region);
    if (!Number.isSafeInteger(regionId) || regionId <= 0) continue;
    const qualified = bestUnlimitedRank(aggregate.type, visited, Number(aggregate.owned));
    if (qualified === null) continue;

    const prior = previous.get(`${aggregate.type}:${aggregate.region}`);
    const rank = Math.min(prior?.rank_number ?? Infinity, qualified);
    if (prior && prior.rank_number === rank && prior.visit_count === visited &&
        prior.owned_count === Number(aggregate.owned)) {
      continue;
    }
    writes.push({
      user_id: userId,
      region_id: regionId,
      region_type: aggregate.type,
      visit_count: visited,
      owned_count: Number(aggregate.owned),
      rank_number: rank,
    });
    changed.push({ id: regionId, type: aggregate.type, number: rank, visited, owned: Number(aggregate.owned) });
  }

  if (writes.length) {
    await executor.execute(sql`
      insert into ${playerRanking} (user_id, region_id, region_type, visit_count, owned_count, rank_number)
      select user_id, region_id, region_type, visit_count, owned_count, rank_number
      from jsonb_to_recordset(${JSON.stringify(writes)}::jsonb) as payload(
        user_id text, region_id bigint, region_type text, visit_count integer, owned_count integer, rank_number integer
      )
      on conflict (user_id, region_type, region_id) do update set
        visit_count = excluded.visit_count,
        owned_count = excluded.owned_count,
        rank_number = excluded.rank_number
    `);
  }

  return changed;
}
