import { PgDialect } from "drizzle-orm/pg-core";
import type { SQL } from "drizzle-orm";
import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("@/lib/db", () => ({ db: { transaction: vi.fn() } }));
vi.mock("@/lib/rankings/sync-player-rankings", () => ({ syncPlayerRankings: vi.fn() }));
vi.mock("./hex-info", () => ({ getHexInfo: vi.fn() }));
vi.mock("@/lib/regions/country-regions", () => ({
  regionIdForPoint: vi.fn(() => BigInt(42)),
  stateIdForPoint: vi.fn(() => BigInt(0)),
  suburbIdForPoint: vi.fn(() => BigInt(0)),
}));

import { db } from "@/lib/db";
import { hexDetails, hexVisit } from "@/db/schema";
import { regionIdForPoint, stateIdForPoint, suburbIdForPoint } from "@/lib/regions/country-regions";
import { syncPlayerRankings } from "@/lib/rankings/sync-player-rankings";
import { ingestVisits } from "./ingest-visits";
import { getHexInfo } from "./hex-info";
import { parseVisitBatch } from "./visit-batch";

const cell = "8a2830828007fff";
const cellId = BigInt(`0x${cell}`);
const timestamp = "2026-11-20T10:00:00Z";
const batch = (score = 0.5, time = timestamp) => parseVisitBatch({ visits: [{ id: "1", cell, timestamp: time, score }] });
const dialect = new PgDialect();
const query = (value: SQL) => dialect.sqlToQuery(value);

function harness(previous = "0", current = "0.5", latest = timestamp,
  uploaded: { id: string; cell: bigint; count: number }[] = [],
  knownRegions: { cell: bigint; regionCountry: bigint | null; regionState: bigint | null; regionSuburb?: bigint | null }[] = []) {
  const lock = vi.fn().mockResolvedValue([{ id: "u1" }]);
  const dayRows = previous === "0" ? [] : [{ userId: "u1", cell: cellId, day: "2026-11-20", score: previous }];
  const select = vi.fn()
    .mockReturnValueOnce({ from: () => ({ where: () => ({ for: lock }) }) })
    .mockReturnValueOnce({ from: () => ({ where: vi.fn().mockResolvedValue(knownRegions) }) })
    .mockReturnValueOnce({ from: () => ({ where: vi.fn().mockResolvedValue(dayRows) }) })
    .mockReturnValueOnce({ from: () => ({ where: vi.fn().mockResolvedValue(uploaded) }) });
  const dailyReturning = vi.fn().mockResolvedValue([{ userId: "u1", cell: cellId, day: "2026-11-20", score: current }]);
  const upsert = vi.fn().mockReturnValue({ returning: dailyReturning });
  const regionConflict = vi.fn().mockResolvedValue([]);
  const detailValues = vi.fn(() => ({ onConflictDoNothing: regionConflict, onConflictDoUpdate: upsert }));
  const insert = vi.fn()
    .mockReturnValueOnce({ values: () => ({ onConflictDoNothing: vi.fn().mockResolvedValue([]) }) })
    .mockReturnValueOnce({ values: detailValues })
    .mockReturnValueOnce({ values: () => ({ onConflictDoUpdate: upsert }) })
    .mockReturnValueOnce({ values: () => ({ onConflictDoUpdate: vi.fn().mockResolvedValue([]) }) });
  const returning = vi.fn().mockResolvedValue([{ cell: cellId, lastVisit: new Date(latest), score: current, lastScore: current, total: 1 }]);
  const where = vi.fn().mockReturnValue({ returning });
  const set = vi.fn().mockReturnValue({ where });
  const update = vi.fn().mockReturnValue({ set });
  const tx = { select, insert, update };
  vi.mocked(db.transaction).mockImplementationOnce(async (callback) => callback(tx as never));
  return { lock, select, insert, detailValues, regionConflict, upsert, dailyReturning, returning, where, set };
}

beforeEach(() => {
  vi.resetAllMocks();
  vi.mocked(getHexInfo).mockResolvedValue({ totals: { totalVisits: 1, rivalScore: 0 }, regions: null, userVisit: null });
  vi.mocked(syncPlayerRankings).mockResolvedValue([]);
  vi.mocked(regionIdForPoint).mockReturnValue(BigInt(42));
  vi.mocked(stateIdForPoint).mockReturnValue(BigInt(0));
  vi.mocked(suburbIdForPoint).mockReturnValue(BigInt(0));
});

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
    const otherId = BigInt(`0x${other}`);
    const mock = harness("0.5", "1");
    mock.dailyReturning.mockResolvedValueOnce([
      { userId: "u1", cell: cellId, day: "2026-11-19", score: "0.25" },
      { userId: "u1", cell: cellId, day: "2026-11-20", score: "1" },
      { userId: "u1", cell: otherId, day: "2026-11-20", score: "0.5" },
    ]);
    mock.returning
      .mockResolvedValueOnce([{ cell: cellId, lastVisit: new Date(timestamp), score: "1.25", lastScore: "1" }])
      .mockResolvedValueOnce([{ cell: otherId, lastVisit: new Date(timestamp), score: "0.5", lastScore: "0.5" }]);
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
    expect(result.hexInfos.map((info) => info.cell)).toEqual([cell, other]);
    expect(getHexInfo).toHaveBeenCalledTimes(2);
  });

  it.each([[0, 7, 7], [7, 7, 0], [7, 10, 3], [10, 7, 0]])(
    "counts only new visits for uploaded=%s, incoming=%s", async (previousCount, count, gain) => {
      const mock = harness("0", "0", timestamp, previousCount ? [{ id: "1", cell: cellId, count: previousCount }] : []);
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
    expect(query(mock.where.mock.calls[0][0]).params).toEqual(["other-player", cellId]);
  });

  it("classifies unmapped cells into hex_details from the cell center", async () => {
    const mock = harness();
    await ingestVisits("u1", batch());
    expect(regionIdForPoint).toHaveBeenCalledTimes(1);
    const [latitude, longitude] = vi.mocked(regionIdForPoint).mock.calls[0];
    expect(latitude).toBeGreaterThan(-90);
    expect(latitude).toBeLessThan(90);
    expect(longitude).toBeGreaterThan(-180);
    expect(longitude).toBeLessThanOrEqual(180);
    expect(mock.insert).toHaveBeenCalledWith(hexDetails);
    expect(mock.regionConflict).toHaveBeenCalledTimes(1);
  });

  it.each([
    [BigInt(42), BigInt(7)],
    [BigInt(42), null],
    [null, null],
  ])("skips classification for cached country=%s state=%s", async (regionCountry, regionState) => {
    const mock = harness("0", "0.5", timestamp, [], [
      { cell: cellId, regionCountry, regionState, regionSuburb: null },
    ]);
    await ingestVisits("u1", batch());
    expect(regionIdForPoint).not.toHaveBeenCalled();
    expect(stateIdForPoint).not.toHaveBeenCalled();
    expect(suburbIdForPoint).not.toHaveBeenCalled();
    expect(vi.mocked(mock.insert).mock.calls.map(([table]) => table)).not.toContain(hexDetails);
  });

  it("writes country, state, and suburb in a single conflict-safe row", async () => {
    vi.mocked(stateIdForPoint).mockReturnValueOnce(BigInt(7));
    vi.mocked(suburbIdForPoint).mockReturnValueOnce(BigInt(99));
    const mock = harness();
    await ingestVisits("u1", batch());
    expect(stateIdForPoint).toHaveBeenCalledWith(BigInt(42), expect.any(Number), expect.any(Number));
    expect(suburbIdForPoint).toHaveBeenCalledWith(BigInt(7), expect.any(Number), expect.any(Number));
    expect(mock.detailValues).toHaveBeenCalledWith([
      { cell: cellId, regionCountry: BigInt(42), regionState: BigInt(7), regionSuburb: BigInt(99) },
    ]);
    expect(mock.regionConflict).toHaveBeenCalledTimes(1);
  });

  it("caches a state without a matching suburb", async () => {
    vi.mocked(stateIdForPoint).mockReturnValueOnce(BigInt(7));
    const mock = harness();
    await ingestVisits("u1", batch());
    expect(suburbIdForPoint).toHaveBeenCalledWith(BigInt(7), expect.any(Number), expect.any(Number));
    expect(mock.detailValues).toHaveBeenCalledWith([
      { cell: cellId, regionCountry: BigInt(42), regionState: BigInt(7), regionSuburb: null },
    ]);
  });

  it("caches a country without a matching state", async () => {
    const mock = harness();
    await ingestVisits("u1", batch());
    expect(suburbIdForPoint).not.toHaveBeenCalled();
    expect(mock.detailValues).toHaveBeenCalledWith([
      { cell: cellId, regionCountry: BigInt(42), regionState: null, regionSuburb: null },
    ]);
  });

  it("caches cells outside all countries with null regions", async () => {
    vi.mocked(regionIdForPoint).mockReturnValueOnce(BigInt(0));
    const mock = harness();
    await ingestVisits("u1", batch());
    expect(stateIdForPoint).not.toHaveBeenCalled();
    expect(suburbIdForPoint).not.toHaveBeenCalled();
    expect(mock.detailValues).toHaveBeenCalledWith([
      { cell: cellId, regionCountry: null, regionState: null, regionSuburb: null },
    ]);
  });

  it("classifies a cell only once across repeated visits", async () => {
    const mock = harness();
    await ingestVisits("u1", parseVisitBatch({ visits: [
      { id: "1", cell, timestamp, score: 0.5 },
      { id: "2", cell, timestamp, score: 0.5 },
    ] }));
    expect(regionIdForPoint).toHaveBeenCalledTimes(1);
    expect(mock.detailValues).toHaveBeenCalledWith([
      { cell: cellId, regionCountry: BigInt(42), regionState: null, regionSuburb: null },
    ]);
  });

  it("returns fresh HexInfo once per touched cell after updating visits, including retries", async () => {
    const mock = harness("0.5", "0.5", timestamp, [{ id: "1", cell: cellId, count: 1 }]);
    const info = {
      totals: { totalVisits: 8, rivalScore: 2 },
      regions: null,
      userVisit: { cell, total: 1, lastVisit: timestamp, score: 0.5, lastScore: 0.5 },
    };
    vi.mocked(getHexInfo).mockImplementation(async (_userId, _cell, executor) => {
      expect(mock.set).toHaveBeenCalledTimes(1);
      expect(executor?.select).toBe(mock.select);
      return info;
    });
    const result = await ingestVisits("u1", parseVisitBatch({ visits: [
      { id: "1", cell, timestamp, score: 0.5 },
      { id: "2", cell, timestamp, score: 0.5 },
    ] }));
    expect(getHexInfo).toHaveBeenCalledExactlyOnceWith("u1", cellId, expect.anything());
    expect(result.hexInfos).toEqual([{ cell, ...info }]);
  });

  it("refreshes player rankings inside the transaction and returns changed rows", async () => {
    const mock = harness();
    const rankings = [{ id: 1, type: "global" as const, number: 20, visited: 3, owned: 1 }];
    vi.mocked(syncPlayerRankings).mockResolvedValueOnce(rankings);
    const result = await ingestVisits("u1", batch());
    expect(syncPlayerRankings).toHaveBeenCalledWith("u1", expect.objectContaining({ select: mock.select }));
    expect(result.rankings).toEqual(rankings);
  });

  it("does not acknowledge if HexInfo cannot be loaded", async () => {
    harness();
    vi.mocked(getHexInfo).mockRejectedValueOnce(new Error("projection failed"));
    await expect(ingestVisits("u1", batch())).rejects.toThrow("projection failed");
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
