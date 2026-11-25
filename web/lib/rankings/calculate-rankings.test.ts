import { beforeEach, describe, expect, it, vi } from "vitest";
import { PgDialect } from "drizzle-orm/pg-core";
import type { SQLWrapper } from "drizzle-orm";

const { execute } = vi.hoisted(() => ({ execute: vi.fn() }));
vi.mock("@/lib/db", () => ({
  db: { transaction: vi.fn((callback: (tx: unknown) => unknown) => callback({ execute })) },
}));

import { calculateRankings } from "./calculate-rankings";

const queries = () => execute.mock.calls.map(([statement]) => new PgDialect().sqlToQuery((statement as SQLWrapper).getSQL()));
const payload = () => JSON.parse(queries()[3].params[0] as string);
const ranking = (user_id: string, region_id: number, region_type: string, rank_number: number, visit_count: number, owned_count: number) =>
  ({ user_id, region_id, region_type, rank_number, visit_count, owned_count });

beforeEach(() => {
  execute.mockReset();
  execute.mockResolvedValue([]);
});

describe("calculateRankings", () => {
  it("locks, aggregates per country, deletes old rows, and inserts flat rankings", async () => {
    execute
      .mockResolvedValueOnce([])
      .mockResolvedValueOnce([
        { user_id: "a", type: "country", region: "100", visited: 1500, owned: 1200, score: 1500 },
        { user_id: "b", type: "country", region: "100", visited: 3, owned: 0, score: 2 },
        { user_id: "a", type: "country", region: "200", visited: 1, owned: 1, score: 1 },
        { user_id: "c", type: "country", region: "100", visited: 0, owned: 4, score: 8 },
        { user_id: "c", type: "country", region: "0", visited: 3, owned: 3, score: 3 },
      ]);
    const summary = await calculateRankings();
    expect(summary).toMatchObject({ regions: 2, players: 3, assignments: 3 });

    const [lock, aggregate, reset, write] = queries();
    expect(lock.sql).toBe("select pg_advisory_xact_lock(hashtext('calculate_rankings'))");
    expect(aggregate.sql).toContain('rank() over (partition by "hex_visit"."cell"');
    expect(aggregate.sql).toContain("('country', \"hex_details\".\"region_country\")");
    expect(aggregate.sql).toContain("('suburb', \"hex_details\".\"region_suburb\")");
    expect(aggregate.sql).toContain("where regions.id is not null");
    expect(aggregate.sql).toContain("group by cells.user_id, regions.type, regions.id");
    expect(aggregate.sql).toContain("count(*) filter (where cells.position = 1 and cells.tied = 1 and cells.score > 0)");
    expect(reset.sql).toBe('delete from "player_ranking"');
    expect(write.sql).toContain('insert into "player_ranking" (user_id, region_id, region_type, visit_count, owned_count, rank_number)');
    expect(write.sql).toContain("jsonb_to_recordset");
    expect(payload()).toEqual([
      ranking("a", 100, "country", 1, 1500, 1200),
      ranking("b", 100, "country", 15, 3, 0),
      ranking("a", 200, "country", 15, 1, 1),
    ]);
  });

  it("allocates country and suburb ranks independently even when region ids match", async () => {
    execute
      .mockResolvedValueOnce([])
      .mockResolvedValueOnce([
        { user_id: "a", type: "suburb", region: "100", visited: 20, owned: 20, score: 40 },
        { user_id: "b", type: "suburb", region: "100", visited: 20, owned: 20, score: 30 },
        { user_id: "c", type: "suburb", region: "100", visited: 10, owned: 10, score: 10 },
        { user_id: "d", type: "suburb", region: "100", visited: 5, owned: 5, score: 5 },
        { user_id: "e", type: "suburb", region: "100", visited: 2, owned: 2, score: 2 },
        { user_id: "f", type: "suburb", region: "100", visited: 1, owned: 0, score: 1 },
        { user_id: "g", type: "suburb", region: "100", visited: 0, owned: 0, score: 0 },
        { user_id: "a", type: "country", region: "100", visited: 20, owned: 20, score: 40 },
        { user_id: "a", type: "suburb", region: "200", visited: 20, owned: 20, score: 40 },
      ]);

    expect(await calculateRankings()).toMatchObject({ regions: 3, players: 7, assignments: 8 });
    expect(payload()).toEqual([
      ranking("a", 100, "country", 12, 20, 20),
      ranking("a", 100, "suburb", 1, 20, 20),
      ranking("b", 100, "suburb", 2, 20, 20),
      ranking("c", 100, "suburb", 3, 10, 10),
      ranking("d", 100, "suburb", 4, 5, 5),
      ranking("e", 100, "suburb", 5, 2, 2),
      ranking("f", 100, "suburb", 6, 1, 0),
      ranking("a", 200, "suburb", 1, 20, 20),
    ]);
  });

  it("allocates global titles independently with one emperor and worldwide totals", async () => {
    execute.mockResolvedValueOnce([]).mockResolvedValueOnce([
      { user_id: "a", type: "global", region: "1", visited: 12000, owned: 11000, score: 22000 },
      { user_id: "b", type: "global", region: "1", visited: 11000, owned: 10000, score: 20000 },
      { user_id: "a", type: "country", region: "1", visited: 6000, owned: 5500, score: 11000 },
      { user_id: "c", type: "global", region: "1", visited: 1, owned: 0, score: 1 },
      { user_id: "d", type: "global", region: "1", visited: 0, owned: 0, score: 0 },
    ]);
    expect(await calculateRankings()).toMatchObject({ regions: 2, players: 4, assignments: 4 });
    const aggregate = queries()[1].sql;
    expect(aggregate).toContain('left join "hex_details"');
    expect(aggregate).toContain("('global', 1::bigint)");
    expect(payload()).toEqual([
      ranking("a", 1, "global", 1, 12000, 11000),
      ranking("b", 1, "global", 2, 11000, 10000),
      ranking("c", 1, "global", 20, 1, 0),
      ranking("a", 1, "country", 1, 6000, 5500),
    ]);
  });

  it("only deletes rankings when nobody has visited a region", async () => {
    expect(await calculateRankings()).toMatchObject({ regions: 0, players: 0, assignments: 0 });
    expect(execute).toHaveBeenCalledTimes(3);
    expect(queries()[2].sql).toBe('delete from "player_ranking"');
  });

  it("deletes stale rankings when players no longer qualify for assignments", async () => {
    execute.mockResolvedValueOnce([]).mockResolvedValueOnce([
      { user_id: "a", type: "country", region: "100", visited: 0, owned: 1, score: 1 },
    ]);
    expect(await calculateRankings()).toMatchObject({ regions: 1, players: 1, assignments: 0 });
    expect(execute).toHaveBeenCalledTimes(3);
    expect(queries()[2].sql).toBe('delete from "player_ranking"');
  });

  it("propagates insert failures out of the transaction", async () => {
    execute.mockResolvedValueOnce([]).mockResolvedValueOnce([
      { user_id: "a", type: "country", region: "100", visited: 1, owned: 0, score: 1 },
    ]).mockResolvedValueOnce([]).mockRejectedValueOnce(new Error("write failed"));
    await expect(calculateRankings()).rejects.toThrow("write failed");
    expect(queries()[2].sql).toBe('delete from "player_ranking"');
  });
});
