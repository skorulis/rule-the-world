import { sql } from "drizzle-orm";
import { playerRanking } from "@/db/schema";
import { db } from "@/lib/db";
import { loadRegionAggregates } from "./aggregates";
import { allocateRanks, type RegionPlayer } from "./allocate";
import { countryRanks, globalRanks, stateRanks, suburbRanks } from "./ranks";

export interface RankingsSummary {
  regions: number;
  players: number;
  assignments: number;
  durationMs: number;
}

/** Recalculates every player's country rank and replaces `user.rankings` in one transaction. */
export async function calculateRankings(): Promise<RankingsSummary> {
  const started = Date.now();
  return db.transaction(async (tx) => {
    await tx.execute(sql`select pg_advisory_xact_lock(hashtext('calculate_rankings'))`);

    const rows = await loadRegionAggregates(tx);

    const regions = new Map<string, { id: number; type: "global" | "country" | "state" | "suburb"; players: RegionPlayer[] }>();
    for (const row of rows) {
      const id = Number(row.region);
      if (!Number.isSafeInteger(id) || id <= 0) continue;
      const key = `${row.type}:${id}`;
      const region = regions.get(key) ?? { id, type: row.type, players: [] };
      region.players.push({ userId: row.user_id, owned: Number(row.owned), visited: Number(row.visited), score: Number(row.score) });
      regions.set(key, region);
    }

    const rankings: {
      user_id: string;
      region_id: number;
      region_type: "global" | "country" | "state" | "suburb";
      visit_count: number;
      owned_count: number;
      rank_number: number;
    }[] = [];
    let assignments = 0;
    const priority = { global: 0, country: 1, state: 2, suburb: 3 };
    const definitions = { global: globalRanks, country: countryRanks, state: stateRanks, suburb: suburbRanks };
    const ordered = [...regions.values()].sort((a, b) =>
      priority[a.type] - priority[b.type] || a.id - b.id);
    for (const { id, type, players } of ordered) {
      const byId = new Map(players.map((player) => [player.userId, player]));
      for (const [userId, number] of allocateRanks(players, definitions[type])) {
        const player = byId.get(userId);
        rankings.push({ user_id: userId, region_id: id, region_type: type,
          rank_number: number, visit_count: player?.visited ?? 0, owned_count: player?.owned ?? 0 });
        assignments += 1;
      }
    }

    await tx.execute(sql`delete from ${playerRanking}`);
    if (rankings.length) {
      await tx.execute(sql`
        insert into ${playerRanking} (user_id, region_id, region_type, visit_count, owned_count, rank_number)
        select user_id, region_id, region_type, visit_count, owned_count, rank_number
        from jsonb_to_recordset(${JSON.stringify(rankings)}::jsonb) as payload(
          user_id text, region_id bigint, region_type text, visit_count integer, owned_count integer, rank_number integer
        )
      `);
    }

    return {
      regions: regions.size,
      players: new Set(rows.map((row) => row.user_id)).size,
      assignments,
      durationMs: Date.now() - started,
    };
  });
}
