import { PgDialect } from "drizzle-orm/pg-core";
import type { SQL } from "drizzle-orm";
import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("@/lib/db", () => ({ db: { transaction: vi.fn() } }));
vi.mock("@/lib/regions/country-regions", () => ({ regionIdForPoint: vi.fn(() => "42") }));

import { db } from "@/lib/db";
import { hexRegion, hexVisit } from "@/db/schema";
import { regionIdForPoint } from "@/lib/regions/country-regions";
import { ingestVisits } from "./ingest-visits";
import { parseVisitBatch } from "./visit-batch";

const cell = "8a2830828007fff";
const timestamp = "2026-11-20T10:00:00Z";
const batch = (score = 0.5, time = timestamp) => parseVisitBatch({ visits: [{ id: "1", cell, timestamp: time, score }] });
const dialect = new PgDialect();
const query = (value: SQL) => dialect.sqlToQuery(value);

function harness(previous = "0", current = "0.5", latest = timestamp,
  uploaded: { id: string; cell: string; count: number }[] = [], knownRegions: string[] = []) {
  const lock = vi.fn().mockResolvedValue([{ id: "u1" }]);
  const dayRows = previous === "0" ? [] : [{ userId: "u1", cell, day: "2026-11-20", score: previous }];
  const select = vi.fn()
    .mockReturnValueOnce({ from: () => ({ where: () => ({ for: lock }) }) })
    .mockReturnValueOnce({ from: () => ({ where: vi.fn().mockResolvedValue(knownRegions.map((c) => ({ cell: c }))) }) })
    .mockReturnValueOnce({ from: () => ({ where: vi.fn().mockResolvedValue(dayRows) }) })
    .mockReturnValueOnce({ from: () => ({ where: vi.fn().mockResolvedValue(uploaded) }) });
  const dailyReturning = vi.fn().mockResolvedValue([{ userId: "u1", cell, day: "2026-11-20", score: current }]);
  const upsert = vi.fn().mockReturnValue({ returning: dailyReturning });
  const regionConflict = vi.fn().mockResolvedValue([]);
  const insert = vi.fn()
    .mockReturnValueOnce({ values: () => ({ onConflictDoNothing: vi.fn().mockResolvedValue([]) }) })
    .mockReturnValueOnce({ values: () => ({ onConflictDoNothing: regionConflict, onConflictDoUpdate: upsert }) })
    .mockReturnValueOnce({ values: () => ({ onConflictDoUpdate: upsert }) })
    .mockReturnValueOnce({ values: () => ({ onConflictDoUpdate: vi.fn().mockResolvedValue([]) }) });
  const returning = vi.fn().mockResolvedValue([{ cell, lastVisit: new Date(latest), score: current, lastScore: current, total: 1 }]);
  const where = vi.fn().mockReturnValue({ returning });
  const set = vi.fn().mockReturnValue({ where });
  const update = vi.fn().mockReturnValue({ set });
  const tx = { select, insert, update };
  vi.mocked(db.transaction).mockImplementationOnce(async (callback) => callback(tx as never));
  return { lock, select, insert, regionConflict, upsert, dailyReturning, returning, where, set };
}

beforeEach(() => vi.resetAllMocks());

describe("visit ingestion SQL contract", () => {
  it.each([
    ["0", "0.5", 0.5],
    ["0.5", "0.5", 0.5],
    ["0.5", "1", 1],
    ["1", "1", 0.25],
  ])("uses exact numeric deltas for old=%s, new=%s, incoming=%s", async (previous, current, incoming) => {
    const mock = harness(previous, current);
    const result = await ingestVisits("u1", batch(incoming));
    expect(mock.lock).toHaveBeenCalledWith("update");
    expect(mock.insert).toHaveBeenCalledWith(hexVisit);
    expect(query(mock.upsert.mock.calls[0][0].set.score).sql).toContain("greatest");
    const score = query(mock.set.mock.calls[0][0].score);
    expect(score.sql).toContain("::numeric -");
    expect(score.params).toEqual([current, previous]);
    expect(result.acceptedIds).toEqual(["1"]);
    expect(result.visits[0].score).toBe(Number(current));
  });

  it("keeps lastVisit monotonic and derives lastScore from its UTC day for older uploads", async () => {
    const mock = harness("0", "0.5", "2026-11-22T10:00:00Z");
    await ingestVisits("u1", batch(0.5, "2026-11-19T10:00:00Z"));
    const update = mock.set.mock.calls[0][0];
    expect(query(update.lastVisit).sql).toContain("greatest");
    expect(query(update.lastVisit).params).toEqual(["2026-11-19T10:00:00.000Z"]);
    expect(query(update.lastScore).sql).toContain("at time zone 'UTC'");
    expect(query(update.lastScore).params).toContain("u1");
  });

  it("separates per-cell deltas across overlapping days and multiple cells", async () => {
    const other = "8a2830828017fff";
    const mock = harness("0.5", "1");
    mock.dailyReturning.mockResolvedValueOnce([
      { userId: "u1", cell, day: "2026-11-19", score: "0.25" },
      { userId: "u1", cell, day: "2026-11-20", score: "1" },
      { userId: "u1", cell: other, day: "2026-11-20", score: "0.5" },
    ]);
    mock.returning
      .mockResolvedValueOnce([{ cell, lastVisit: new Date(timestamp), score: "1.25", lastScore: "1" }])
      .mockResolvedValueOnce([{ cell: other, lastVisit: new Date(timestamp), score: "0.5", lastScore: "0.5" }]);
    const result = await ingestVisits("u1", parseVisitBatch({ visits: [
      { id: "1", cell: other, timestamp, score: 0.5 },
      { id: "2", cell, timestamp, score: 1 },
      { id: "3", cell, timestamp: "2026-11-19T10:00:00Z", score: 0.25 },
    ] }));
    expect(query(mock.set.mock.calls[0][0].score).params).toEqual(["0.25", "0", "1", "0.5"]);
    expect(query(mock.set.mock.calls[1][0].score).params).toEqual(["0.5", "0"]);
    expect(result.visits.map((row) => [row.cell, row.score, row.lastScore])).toEqual([
      [cell, 1.25, 1], [other, 0.5, 0.5],
    ]);
    expect(result.acceptedIds).toEqual(["1", "2", "3"]);
  });

  it.each([[0, 7, 7], [7, 7, 0], [7, 10, 3], [10, 7, 0]])(
    "counts only new visits for uploaded=%s, incoming=%s", async (previousCount, count, gain) => {
      const mock = harness("0", "0", timestamp, previousCount ? [{ id: "1", cell, count: previousCount }] : []);
      const result = await ingestVisits("u1", parseVisitBatch({ visits: [{ id: "1", cell, timestamp, score: 0, count }] }));
      expect(query(mock.set.mock.calls[0][0].total).params).toEqual([gain]);
      expect(result.visits[0].total).toBe(1);
    },
  );

  it("retains zero-score visits", async () => {
    harness("0", "0");
    expect((await ingestVisits("u1", batch(0))).visits[0].score).toBe(0);
  });

  it("scopes aggregate updates to the authenticated player", async () => {
    const mock = harness();
    await ingestVisits("other-player", batch());
    expect(query(mock.where.mock.calls[0][0]).params).toEqual(["other-player", cell]);
  });

  it("classifies unmapped cells into hex_region from the cell center", async () => {
    const mock = harness();
    await ingestVisits("u1", batch());
    expect(regionIdForPoint).toHaveBeenCalledTimes(1);
    const [latitude, longitude] = vi.mocked(regionIdForPoint).mock.calls[0];
    expect(latitude).toBeGreaterThan(-90);
    expect(latitude).toBeLessThan(90);
    expect(longitude).toBeGreaterThan(-180);
    expect(longitude).toBeLessThanOrEqual(180);
    expect(mock.insert).toHaveBeenCalledWith(hexRegion);
    expect(mock.regionConflict).toHaveBeenCalledTimes(1);
  });

  it("skips region lookup for cells already classified", async () => {
    const mock = harness("0", "0.5", timestamp, [], [cell]);
    await ingestVisits("u1", batch());
    expect(regionIdForPoint).not.toHaveBeenCalled();
    expect(vi.mocked(mock.insert).mock.calls.map(([table]) => table)).not.toContain(hexRegion);
  });

  it("propagates transaction failures without acknowledging", async () => {
    const mock = harness();
    mock.dailyReturning.mockRejectedValueOnce(new Error("write failed"));
    await expect(ingestVisits("u1", batch())).rejects.toThrow("write failed");
    expect(mock.set).not.toHaveBeenCalled();
  });

  it("does not write for a user deleted before the transaction lock", async () => {
    const mock = harness();
    mock.lock.mockResolvedValueOnce([]);
    await expect(ingestVisits("u1", batch())).rejects.toThrow("no longer exists");
    expect(mock.insert).not.toHaveBeenCalled();
  });
});
