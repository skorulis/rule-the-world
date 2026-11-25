import { sql } from "drizzle-orm";
import { hexDetails, hexVisit, playerRanking } from "@/db/schema";
import { db } from "@/lib/db";
import { allocateRanks, type RegionPlayer } from "./allocate";
import { countryRanks, globalRanks, suburbRanks } from "./ranks";

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

    const rows = await tx.execute<{
      user_id: string;
      region: string;
      type: "global" | "country" | "suburb";
      visited: number;
      owned: number;
      score: number;
    }>(sql`
      with cells as (
        select ${hexVisit.userId} as user_id, ${hexVisit.cell} as cell, ${hexVisit.score} as score,
          ${hexVisit.total} > 0 as visited,
          rank() over (partition by ${hexVisit.cell} order by ${hexVisit.score} desc) as position,
          count(*) over (partition by ${hexVisit.cell}, ${hexVisit.score}) as tied
        from ${hexVisit}
      )
      select cells.user_id, regions.id::text as region, regions.type,
        count(*) filter (where cells.visited)::int as visited,
        count(*) filter (where cells.position = 1 and cells.tied = 1 and cells.score > 0)::int as owned,
        coalesce(sum(cells.score), 0)::float8 as score
      from cells
      left join ${hexDetails} on ${hexDetails.cell} = cells.cell
      cross join lateral (values
        ('global', 1::bigint),
        ('country', ${hexDetails.regionCountry}),
        ('suburb', ${hexDetails.regionSuburb})
      ) as regions(type, id)
      where regions.id is not null
      group by cells.user_id, regions.type, regions.id
    `);

    const regions = new Map<string, { id: number; type: "global" | "country" | "suburb"; players: RegionPlayer[] }>();
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
      region_type: "global" | "country" | "suburb";
      visit_count: number;
      owned_count: number;
      rank_number: number;
    }[] = [];
    let assignments = 0;
    const priority = { global: 0, country: 1, suburb: 2 };
    const definitions = { global: globalRanks, country: countryRanks, suburb: suburbRanks };
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
