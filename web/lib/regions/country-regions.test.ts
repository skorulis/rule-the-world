import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { regionIdForPoint, stateIdForPoint, suburbIdForPoint } from "./country-regions";

const NONE = BigInt(0);

describe("regionIdForPoint", () => {
  it("returns a region id for a point inside a country", () => {
    expect(regionIdForPoint(48.85, 2.35)).not.toBe(NONE);
  });

  it("returns the same region for another point in the same country", () => {
    expect(regionIdForPoint(48.85, 2.35)).toBe(regionIdForPoint(45.76, 4.83));
  });

  it("returns different ids for different countries", () => {
    expect(regionIdForPoint(48.85, 2.35)).not.toBe(regionIdForPoint(40.42, -3.7));
  });

  it("returns 'none' for open ocean", () => {
    expect(regionIdForPoint(-30, -40)).toBe(NONE);
    expect(regionIdForPoint(0, -150)).toBe(NONE);
  });

  it("returns 'none' for out-of-range or non-finite input", () => {
    expect(regionIdForPoint(91, 0)).toBe(NONE);
    expect(regionIdForPoint(-91, 0)).toBe(NONE);
    expect(regionIdForPoint(Number.NaN, 0)).toBe(NONE);
    expect(regionIdForPoint(0, Number.NaN)).toBe(NONE);
  });

  it("handles antimeridian longitude wrap", () => {
    expect(regionIdForPoint(48.85, 182.35)).toBe(regionIdForPoint(48.85, -177.65));
  });
});

describe("stateIdForPoint", () => {
  const AUSTRALIA = regionIdForPoint(-25, 134);

  it("returns a state id for a point inside an Australian state", () => {
    expect(AUSTRALIA).not.toBe(NONE);
    expect(stateIdForPoint(AUSTRALIA, -33.8, 151.2)).not.toBe(NONE);
  });

  it("returns different ids for different states", () => {
    expect(stateIdForPoint(AUSTRALIA, -33.8, 151.2))
      .not.toBe(stateIdForPoint(AUSTRALIA, -37.8, 145.0));
  });

  it("returns 'none' for a point outside every state of the parent", () => {
    expect(stateIdForPoint(AUSTRALIA, -30, -40)).toBe(NONE);
    expect(stateIdForPoint(AUSTRALIA, 48.85, 2.35)).toBe(NONE);
  });

  it("returns 'none' for a country without states", () => {
    const france = regionIdForPoint(48.85, 2.35);
    expect(france).not.toBe(NONE);
    expect(stateIdForPoint(france, 48.85, 2.35)).toBe(NONE);
  });

  it("returns 'none' for the 'none' region", () => {
    expect(stateIdForPoint(NONE, -33.8, 151.2)).toBe(NONE);
  });
});

describe("suburbIdForPoint", () => {
  const AUSTRALIA = regionIdForPoint(-25, 134);
  const NSW = stateIdForPoint(AUSTRALIA, -33.8, 151.2);
  const moduleDir = path.dirname(fileURLToPath(import.meta.url));
  const hasSuburbData = [
    path.resolve(moduleDir, "../../data/regions/suburbs-medium.geojson"),
    path.resolve(process.cwd(), "data/regions/suburbs-medium.geojson"),
  ].some(existsSync);

  it("returns 'none' for the 'none' region", () => {
    expect(suburbIdForPoint(NONE, -33.8, 151.2)).toBe(NONE);
  });

  it("returns 'none' for a state without suburbs", () => {
    const victoria = stateIdForPoint(AUSTRALIA, -37.8, 145.0);
    expect(victoria).not.toBe(NONE);
    expect(suburbIdForPoint(victoria, -37.8, 145.0)).toBe(NONE);
  });

  it.runIf(hasSuburbData)("returns a suburb id for a point inside a NSW suburb", () => {
    expect(NSW).not.toBe(NONE);
    expect(suburbIdForPoint(NSW, -33.898, 151.179)).not.toBe(NONE);
  });

  it.runIf(hasSuburbData)("returns 'none' for a NSW point outside every suburb", () => {
    expect(suburbIdForPoint(NSW, -33.0, 141.0)).toBe(NONE);
  });
});
