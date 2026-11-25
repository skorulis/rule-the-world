import { sql } from "drizzle-orm";
import { type RegionRanking, user } from "@/db/auth-schema";
import { playerRanking } from "@/db/schema";

export function rankingsForUser() {
  return sql<RegionRanking[]>`(
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', ${playerRanking.regionId}, 'type', ${playerRanking.regionType},
      'number', ${playerRanking.rankNumber}, 'visited', ${playerRanking.visitCount},
      'owned', ${playerRanking.ownedCount}
    ) order by case ${playerRanking.regionType}
      when 'global' then 0 when 'country' then 1 when 'state' then 2 when 'suburb' then 3
    end, ${playerRanking.regionId}), '[]'::jsonb)
    from ${playerRanking}
    where ${playerRanking.userId} = ${user.id}
  )`;
}
