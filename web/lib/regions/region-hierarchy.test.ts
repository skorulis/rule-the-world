import { beforeEach, describe, expect, it, vi } from "vitest";

const files = vi.hoisted(() => new Map<string, string>());
vi.mock("node:fs", () => ({
  readFileSync: vi.fn((filename: string) => {
    const contents = files.get(String(filename).split("/").pop()!);
    if (contents === undefined) throw Object.assign(new Error("Missing fixture"), { code: "ENOENT" });
    return contents;
  }),
}));

function feature(id: string, kind: string, parent: string | undefined, left: number, right: number) {
  return {
    type: "Feature", properties: { id, name: id, kind, ...(parent ? { parent } : {}) },
    geometry: { type: "Polygon", coordinates: [[[left, 0], [right, 0], [right, 4], [left, 4], [left, 0]]] },
  };
}

function setFile(name: string, features: ReturnType<typeof feature>[]) {
  files.set(`${name}-medium.geojson`, JSON.stringify({ type: "FeatureCollection", features }));
}

beforeEach(() => {
  vi.resetModules();
  files.clear();
  setFile("countries", [feature("1", "country", undefined, 0, 2)]);
  setFile("states", [feature("2", "state", "1", 0, 1)]);
  setFile("suburbs", [feature("3", "suburb", "2", 0, 4)]);
});

describe("hierarchyForPoint", () => {
  it("derives parents from suburb metadata outside both coarse parent polygons", async () => {
    const { hierarchyForPoint, regionIdForPoint, stateIdForPoint } = await import("./country-regions");
    expect(regionIdForPoint(2, 3)).toBe(BigInt(0));
    expect(stateIdForPoint(BigInt(1), 2, 3)).toBe(BigInt(0));
    expect(hierarchyForPoint(2, 3)).toEqual({ country: BigInt(1), state: BigInt(2), suburb: BigInt(3) });
  });

  it("retains country/state fallbacks when suburb coverage is unavailable", async () => {
    files.delete("suburbs-medium.geojson");
    const { hierarchyForPoint } = await import("./country-regions");
    expect(hierarchyForPoint(2, 0.5)).toEqual({ country: BigInt(1), state: BigInt(2), suburb: BigInt(0) });
    expect(hierarchyForPoint(2, 1.5)).toEqual({ country: BigInt(1), state: BigInt(0), suburb: BigInt(0) });
    expect(hierarchyForPoint(2, 5)).toEqual({ country: BigInt(0), state: BigInt(0), suburb: BigInt(0) });
  });

  it("rejects orphan suburbs instead of inventing parent regions", async () => {
    setFile("suburbs", [feature("3", "suburb", "99", 0, 4)]);
    const { hierarchyForPoint } = await import("./country-regions");
    expect(() => hierarchyForPoint(2, 3)).toThrow("Invalid suburb parent hierarchy");
  });

  it("resolves shared edges by stable identity, not file order", async () => {
    setFile("suburbs", [feature("4", "suburb", "2", 2, 4), feature("3", "suburb", "2", 0, 2)]);
    const { hierarchyForPoint } = await import("./country-regions");
    expect(hierarchyForPoint(2, 2).suburb).toBe(BigInt(3));
  });

  it("rejects invalid points and still handles longitude wrapping", async () => {
    const { hierarchyForPoint } = await import("./country-regions");
    expect(hierarchyForPoint(2, 363).suburb).toBe(BigInt(3));
    for (const [latitude, longitude] of [[NaN, 3], [91, 3], [2, Infinity]]) {
      expect(hierarchyForPoint(latitude, longitude)).toEqual({ country: BigInt(0), state: BigInt(0), suburb: BigInt(0) });
    }
  });
});
