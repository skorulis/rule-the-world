import { sql } from "drizzle-orm";
import { type RegionRanking, user } from "@/db/auth-schema";
import { hexDetails, hexVisit } from "@/db/schema";
import { db } from "@/lib/db";
import { allocateRanks, type RegionPlayer } from "./allocate";
import { countryRanks, suburbRanks } from "./ranks";

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
      type: "country" | "suburb";
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
      join ${hexDetails} on ${hexDetails.cell} = cells.cell
      cross join lateral (values
        ('country', ${hexDetails.regionCountry}),
        ('suburb', ${hexDetails.regionSuburb})
      ) as regions(type, id)
      where regions.id is not null
      group by cells.user_id, regions.type, regions.id
    `);

    const regions = new Map<string, { id: number; type: "country" | "suburb"; players: RegionPlayer[] }>();
    for (const row of rows) {
      const id = Number(row.region);
      if (!Number.isSafeInteger(id) || id <= 0) continue;
      const key = `${row.type}:${id}`;
      const region = regions.get(key) ?? { id, type: row.type, players: [] };
      region.players.push({ userId: row.user_id, owned: Number(row.owned), visited: Number(row.visited), score: Number(row.score) });
      regions.set(key, region);
    }

    const rankings = new Map<string, RegionRanking[]>();
    let assignments = 0;
    const ordered = [...regions.values()].sort((a, b) =>
      (a.type === b.type ? 0 : a.type === "country" ? -1 : 1) || a.id - b.id);
    for (const { id, type, players } of ordered) {
      const byId = new Map(players.map((player) => [player.userId, player]));
      for (const [userId, number] of allocateRanks(players, type === "country" ? countryRanks : suburbRanks)) {
        const player = byId.get(userId);
        rankings.set(userId, [...rankings.get(userId) ?? [],
          { id, type, number, visited: player?.visited ?? 0, owned: player?.owned ?? 0 }]);
        assignments += 1;
      }
    }

    await tx.execute(sql`update ${user} set "rankings" = '[]'::jsonb where ${user.rankings} <> '[]'::jsonb`);
    if (rankings.size) {
      const payload = JSON.stringify([...rankings].map(([userId, value]) => ({ user_id: userId, rankings: value })));
      await tx.execute(sql`
        update ${user} set "rankings" = payload.rankings
        from jsonb_to_recordset(${payload}::jsonb) as payload(user_id text, rankings jsonb)
        where ${user.id} = payload.user_id
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
