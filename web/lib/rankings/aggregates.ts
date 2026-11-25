import { sql, type SQL } from "drizzle-orm";
import { hexDetails, hexVisit } from "@/db/schema";
import type { db } from "@/lib/db";

export type RankingRegionType = "global" | "country" | "state" | "suburb";

export type RegionAggregate = {
  user_id: string;
  region: string;
  type: RankingRegionType;
  visited: number;
  owned: number;
  score: number;
};

/**
 * Per-player, per-region visit totals. Cell ownership needs every player's rank per cell,
 * so the `cells` CTE always spans all users; `userId` only filters the grouped output.
 */
export function regionAggregates(userId?: string): SQL {
  return sql`
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
      ('state', ${hexDetails.regionState}),
      ('suburb', ${hexDetails.regionSuburb})
    ) as regions(type, id)
    where regions.id is not null
      ${userId ? sql`and cells.user_id = ${userId}` : sql``}
    group by cells.user_id, regions.type, regions.id
  `;
}

export function loadRegionAggregates(
  executor: Pick<typeof db, "execute">,
  userId?: string,
) {
  return executor.execute<RegionAggregate>(regionAggregates(userId));
}
