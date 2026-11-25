import { sql } from "drizzle-orm";
import { PgDialect } from "drizzle-orm/pg-core";
import { describe, expect, it } from "vitest";
import { user } from "@/db/auth-schema";
import { rankingsForUser } from "./query";

const query = () => new PgDialect().sqlToQuery(sql`
  select ${rankingsForUser()} as rankings from ${user} where ${user.id} = ${"u1"}
`);

describe("rankingsForUser", () => {
  it("projects normalized fields into the existing API keys with an empty-array fallback", () => {
    const { sql: statement } = query();
    expect(statement).toContain('from "player_ranking"');
    expect(statement).toContain("coalesce(jsonb_agg(jsonb_build_object(");
    expect(statement).toContain("'id', \"player_ranking\".\"region_id\", 'type', \"player_ranking\".\"region_type\"");
    expect(statement).toContain("'number', \"player_ranking\".\"rank_number\", 'visited', \"player_ranking\".\"visit_count\"");
    expect(statement).toContain("'owned', \"player_ranking\".\"owned_count\"");
    expect(statement).toContain(", '[]'::jsonb)");
    expect(statement).not.toContain('"user"."rankings"');
  });

  it("correlates rankings to the outer user and preserves type/region ordering", () => {
    const { sql: statement, params } = query();
    expect(statement).toContain('where "player_ranking"."user_id" = "user"."id"');
    expect(statement).toContain('order by case "player_ranking"."region_type"');
    expect(statement).toContain("when 'global' then 0 when 'country' then 1 when 'state' then 2 when 'suburb' then 3");
    expect(statement).toContain('end, "player_ranking"."region_id"');
    expect(params).toEqual(["u1"]);
  });
});
