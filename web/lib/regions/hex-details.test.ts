import { cellToLatLng } from "h3-js";
import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("@/lib/db", () => ({ db: { select: vi.fn(), insert: vi.fn() } }));
vi.mock("./country-regions", () => ({
  regionIdForPoint: vi.fn(), stateIdForPoint: vi.fn(), suburbIdForPoint: vi.fn(),
}));

import { hexDetails } from "@/db/schema";
import { db } from "@/lib/db";
import { regionIdForPoint, stateIdForPoint, suburbIdForPoint } from "./country-regions";
import { calculateHexDetails, getOrCreateHexDetails } from "./hex-details";

const cell = BigInt("0x8a2830828007fff");
const details = { cell, regionCountry: BigInt(42), regionState: BigInt(7), regionSuburb: BigInt(99) };

beforeEach(() => {
  vi.resetAllMocks();
  vi.mocked(regionIdForPoint).mockReturnValue(BigInt(42));
  vi.mocked(stateIdForPoint).mockReturnValue(BigInt(7));
  vi.mocked(suburbIdForPoint).mockReturnValue(BigInt(99));
});

function harness(rows: (typeof hexDetails.$inferSelect)[][], inserted: (typeof hexDetails.$inferSelect)[] = []) {
  const limit = vi.fn();
  for (const result of rows) limit.mockResolvedValueOnce(result);
  const where = vi.fn(() => ({ limit }));
  vi.mocked(db.select).mockReturnValue({ from: vi.fn(() => ({ where })) } as never);
  const returning = vi.fn().mockResolvedValue(inserted);
  const conflict = vi.fn(() => ({ returning }));
  const values = vi.fn(() => ({ onConflictDoNothing: conflict }));
  vi.mocked(db.insert).mockReturnValue({ values } as never);
  return { limit, values, conflict };
}

describe("calculateHexDetails", () => {
  it("classifies the hex center into one country/state row", () => {
    expect(calculateHexDetails(cell)).toEqual(details);
    const [latitude, longitude] = cellToLatLng(cell.toString(16));
    expect(regionIdForPoint).toHaveBeenCalledWith(latitude, longitude);
    expect(stateIdForPoint).toHaveBeenCalledWith(BigInt(42), latitude, longitude);
    expect(suburbIdForPoint).toHaveBeenCalledWith(BigInt(7), latitude, longitude);
    expect(db.select).not.toHaveBeenCalled();
    expect(db.insert).not.toHaveBeenCalled();
  });

  it("uses null when the state has no matching suburb", () => {
    vi.mocked(suburbIdForPoint).mockReturnValueOnce(BigInt(0));
    expect(calculateHexDetails(cell)).toEqual({ ...details, regionSuburb: null });
  });

  it("uses null regions without looking up a suburb when the country has no matching state", () => {
    vi.mocked(stateIdForPoint).mockReturnValueOnce(BigInt(0));
    expect(calculateHexDetails(cell)).toEqual({ ...details, regionState: null, regionSuburb: null });
    expect(suburbIdForPoint).not.toHaveBeenCalled();
  });

  it("uses null regions for ocean cells without looking up a state", () => {
    vi.mocked(regionIdForPoint).mockReturnValueOnce(BigInt(0));
    expect(calculateHexDetails(cell)).toEqual({ cell, regionCountry: null, regionState: null, regionSuburb: null });
    expect(stateIdForPoint).not.toHaveBeenCalled();
    expect(suburbIdForPoint).not.toHaveBeenCalled();
  });
});

describe("getOrCreateHexDetails", () => {
  it.each([
    details,
    { ...details, regionSuburb: null },
    { ...details, regionState: null, regionSuburb: null },
    { cell, regionCountry: null, regionState: null, regionSuburb: null },
  ])(
    "returns cached details without recalculating: %s",
    async (cached) => {
      harness([[cached]]);
      expect(await getOrCreateHexDetails(cell)).toEqual(cached);
      expect(regionIdForPoint).not.toHaveBeenCalled();
      expect(stateIdForPoint).not.toHaveBeenCalled();
      expect(suburbIdForPoint).not.toHaveBeenCalled();
      expect(db.insert).not.toHaveBeenCalled();
    },
  );

  it("persists and returns newly calculated details", async () => {
    const mock = harness([[]], [details]);
    expect(await getOrCreateHexDetails(cell)).toEqual(details);
    expect(db.insert).toHaveBeenCalledWith(hexDetails);
    expect(mock.values).toHaveBeenCalledWith(details);
    expect(mock.conflict).toHaveBeenCalledTimes(1);
  });

  it("returns the stored row if another request inserts the same cell first", async () => {
    const concurrent = { ...details, regionState: null, regionSuburb: null };
    const mock = harness([[], [concurrent]]);
    expect(await getOrCreateHexDetails(cell)).toEqual(concurrent);
    expect(mock.limit).toHaveBeenCalledTimes(2);
  });

  it("propagates database failures", async () => {
    const mock = harness([]);
    mock.limit.mockRejectedValueOnce(new Error("unavailable"));
    await expect(getOrCreateHexDetails(cell)).rejects.toThrow("unavailable");
    expect(db.insert).not.toHaveBeenCalled();
  });
});
