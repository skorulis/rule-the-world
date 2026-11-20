import { describe, expect, it } from "vitest";
import { regionIdForPoint, stateIdForPoint } from "./country-regions";

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
