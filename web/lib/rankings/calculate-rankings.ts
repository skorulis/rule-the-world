import { sql } from "drizzle-orm";
import { user } from "@/db/auth-schema";
import { hexDetails, hexVisit } from "@/db/schema";
import { db } from "@/lib/db";
import { allocateRanks, type RegionPlayer } from "./allocate";
import { countryRanks } from "./ranks";

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
      select cells.user_id, ${hexDetails.regionCountry}::text as region,
        count(*) filter (where cells.visited)::int as visited,
        count(*) filter (where cells.visited and cells.position = 1 and cells.tied = 1 and cells.score > 0)::int as owned,
        coalesce(sum(cells.score), 0)::float8 as score
      from cells
      join ${hexDetails} on ${hexDetails.cell} = cells.cell
      where ${hexDetails.regionCountry} is not null
      group by cells.user_id, ${hexDetails.regionCountry}
    `);

    const regions = new Map<string, RegionPlayer[]>();
    for (const row of rows) {
      const players = regions.get(row.region) ?? [];
      players.push({ userId: row.user_id, owned: Number(row.owned), visited: Number(row.visited), score: Number(row.score) });
      regions.set(row.region, players);
    }

    const rankings = new Map<string, Record<string, number>>();
    let assignments = 0;
    for (const [region, players] of regions) {
      for (const [userId, rank] of allocateRanks(players, countryRanks)) {
        rankings.set(userId, { ...rankings.get(userId), [region]: rank });
        assignments += 1;
      }
    }

    await tx.execute(sql`update ${user} set "rankings" = '{}'::jsonb where ${user.rankings} <> '{}'::jsonb`);
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
