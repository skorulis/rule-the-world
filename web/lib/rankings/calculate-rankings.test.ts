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
        { user_id: "a", region: "100", visited: 1500, owned: 1200, score: 1500 },
        { user_id: "b", region: "100", visited: 3, owned: 0, score: 2 },
        { user_id: "a", region: "200", visited: 1, owned: 1, score: 1 },
      ]);
    const summary = await calculateRankings();
    expect(summary).toMatchObject({ regions: 2, players: 2, assignments: 3 });

    const [lock, aggregate, reset, write] = queries();
    expect(lock.sql).toContain("pg_advisory_xact_lock");
    expect(aggregate.sql).toContain("rank() over (partition by \"hex_visit\".\"cell\"");
    expect(aggregate.sql).toContain("\"hex_details\".\"region_country\" is not null");
    expect(aggregate.sql).toContain("cells.position = 1 and cells.tied = 1 and cells.score > 0");
    expect(reset.sql).toContain("update \"user\" set \"rankings\" = '{}'::jsonb");
    expect(write.sql).toContain("jsonb_to_recordset");
    expect(JSON.parse(write.params[0] as string)).toEqual([
      { user_id: "a", rankings: { "100": 1, "200": 15 } },
      { user_id: "b", rankings: { "100": 15 } },
    ]);
  });

  it("only resets rankings when nobody has visited a country", async () => {
    const summary = await calculateRankings();
    expect(summary).toMatchObject({ regions: 0, players: 0, assignments: 0 });
    expect(execute).toHaveBeenCalledTimes(3);
  });
});
