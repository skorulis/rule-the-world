import { PgDialect } from "drizzle-orm/pg-core";
import type { SQLWrapper } from "drizzle-orm";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { syncPlayerRankings } from "./sync-player-rankings";

const execute = vi.fn();
const executor = { execute } as never;
const queries = () => execute.mock.calls.map(([statement]) =>
  new PgDialect().sqlToQuery((statement as SQLWrapper).getSQL()));
const aggregate = (type: string, region: string, visited: number, owned: number, score = visited) =>
  ({ user_id: "u1", type, region, visited, owned, score });
const ranking = (region_type: string, region_id: string, rank_number: number, visit_count: number, owned_count: number) =>
  ({ region_type, region_id, rank_number, visit_count, owned_count });

beforeEach(() => {
  execute.mockReset();
  execute.mockResolvedValue([]);
});

describe("syncPlayerRankings", () => {
  it("scopes the shared aggregation and existing-row lookup to the player", async () => {
    await syncPlayerRankings("u1", executor);
    const [aggregate, existing] = queries();
    expect(aggregate.sql).toContain('rank() over (partition by "hex_visit"."cell"');
    expect(aggregate.sql).toContain("and cells.user_id =");
    expect(aggregate.params).toContain("u1");
    expect(existing.sql).toContain('from "player_ranking"');
    expect(existing.sql).toContain('"player_ranking"."user_id" = ');
    expect(existing.params).toEqual(["u1"]);
    expect(execute).toHaveBeenCalledTimes(2);
  });

  it("inserts the best qualifying unlimited rank for new regions", async () => {
    execute
      .mockResolvedValueOnce([aggregate("global", "1", 5, 30), aggregate("country", "42", 2, 5)])
      .mockResolvedValueOnce([]);
    const changed = await syncPlayerRankings("u1", executor);
    expect(changed).toEqual([
      { id: 1, type: "global", number: 18, visited: 5, owned: 30 },
      { id: 42, type: "country", number: 13, visited: 2, owned: 5 },
    ]);
    const upsert = queries()[2];
    expect(upsert.sql).toContain('insert into "player_ranking"');
    expect(upsert.sql).toContain("jsonb_to_recordset");
    expect(upsert.sql).toContain("on conflict (user_id, region_type, region_id) do update");
    expect(JSON.parse(upsert.params[0] as string)).toEqual([
      { user_id: "u1", region_id: 1, region_type: "global", visit_count: 5, owned_count: 30, rank_number: 18 },
      { user_id: "u1", region_id: 42, region_type: "country", visit_count: 2, owned_count: 5, rank_number: 13 },
    ]);
  });

  it("upgrades an existing row to a better unlimited rank with fresh counts", async () => {
    execute
      .mockResolvedValueOnce([aggregate("global", "1", 5, 30)])
      .mockResolvedValueOnce([ranking("global", "1", 20, 4, 30)]);
    expect(await syncPlayerRankings("u1", executor)).toEqual([
      { id: 1, type: "global", number: 18, visited: 5, owned: 30 },
    ]);
  });

  it("keeps a better limited rank while still refreshing counts", async () => {
    execute
      .mockResolvedValueOnce([aggregate("suburb", "7", 10, 25)])
      .mockResolvedValueOnce([ranking("suburb", "7", 1, 9, 20)]);
    expect(await syncPlayerRankings("u1", executor)).toEqual([
      { id: 7, type: "suburb", number: 1, visited: 10, owned: 25 },
    ]);
    expect(JSON.parse(queries()[2].params[0] as string)[0].rank_number).toBe(1);
  });

  it("writes nothing when counts and rank are already current", async () => {
    execute
      .mockResolvedValueOnce([aggregate("global", "1", 5, 30)])
      .mockResolvedValueOnce([ranking("global", "1", 18, 5, 30)]);
    expect(await syncPlayerRankings("u1", executor)).toEqual([]);
    expect(execute).toHaveBeenCalledTimes(2);
  });

  it("skips regions without visits or valid ids", async () => {
    execute
      .mockResolvedValueOnce([aggregate("global", "1", 0, 0), aggregate("country", "0", 3, 3)])
      .mockResolvedValueOnce([]);
    expect(await syncPlayerRankings("u1", executor)).toEqual([]);
    expect(execute).toHaveBeenCalledTimes(2);
  });
});
