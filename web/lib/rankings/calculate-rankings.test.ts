import { beforeEach, describe, expect, it, vi } from "vitest";
import { PgDialect } from "drizzle-orm/pg-core";
import type { SQLWrapper } from "drizzle-orm";

const { execute } = vi.hoisted(() => ({ execute: vi.fn() }));
vi.mock("@/lib/db", () => ({
  db: { transaction: vi.fn((callback: (tx: unknown) => unknown) => callback({ execute })) },
}));

import { calculateRankings } from "./calculate-rankings";

const queries = () => execute.mock.calls.map(([statement]) => new PgDialect().sqlToQuery((statement as SQLWrapper).getSQL()));

beforeEach(() => {
  execute.mockReset();
  execute.mockResolvedValue([]);
});

describe("calculateRankings", () => {
  it("locks, aggregates per country, resets, and writes rankings", async () => {
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
    expect(lock.sql).toContain("pg_advisory_xact_lock");
    expect(aggregate.sql).toContain("rank() over (partition by \"hex_visit\".\"cell\"");
    expect(aggregate.sql).toContain("('country', \"hex_details\".\"region_country\")");
    expect(aggregate.sql).toContain("('suburb', \"hex_details\".\"region_suburb\")");
    expect(aggregate.sql).toContain("where regions.id is not null");
    expect(aggregate.sql).toContain("group by cells.user_id, regions.type, regions.id");
    expect(aggregate.sql).toContain("count(*) filter (where cells.position = 1 and cells.tied = 1 and cells.score > 0)");
    expect(reset.sql).toContain("update \"user\" set \"rankings\" = '[]'::jsonb");
    expect(write.sql).toContain("jsonb_to_recordset");
    expect(JSON.parse(write.params[0] as string)).toEqual([
      { user_id: "a", rankings: [{ id: 100, type: "country", number: 1 }, { id: 200, type: "country", number: 15 }] },
      { user_id: "b", rankings: [{ id: 100, type: "country", number: 15 }] },
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

    const summary = await calculateRankings();
    expect(summary).toMatchObject({ regions: 3, players: 7, assignments: 8 });
    const payload = JSON.parse(queries()[3].params[0] as string);
    expect(payload).toEqual([
      { user_id: "a", rankings: [
        { id: 100, type: "country", number: 12 },
        { id: 100, type: "suburb", number: 1 },
        { id: 200, type: "suburb", number: 1 },
      ] },
      { user_id: "b", rankings: [{ id: 100, type: "suburb", number: 2 }] },
      { user_id: "c", rankings: [{ id: 100, type: "suburb", number: 3 }] },
      { user_id: "d", rankings: [{ id: 100, type: "suburb", number: 4 }] },
      { user_id: "e", rankings: [{ id: 100, type: "suburb", number: 5 }] },
      { user_id: "f", rankings: [{ id: 100, type: "suburb", number: 6 }] },
    ]);
  });

  it("only resets rankings when nobody has visited a region", async () => {
    const summary = await calculateRankings();
    expect(summary).toMatchObject({ regions: 0, players: 0, assignments: 0 });
    expect(execute).toHaveBeenCalledTimes(3);
  });
});
