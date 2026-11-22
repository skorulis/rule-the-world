import { readFileSync } from "node:fs";
import { decode } from "geobuf";
import Pbf from "pbf";
import { describe, expect, it } from "vitest";

const fixture = new URL("../../../data/regions/geobuf-fixture.pbf", import.meta.url);

describe("Python Geobuf interoperability", () => {
  it("preserves implicit ring closure, six-decimal coordinates, Unicode, holes and multipolygons", () => {
    const collection = decode(new Pbf(readFileSync(fixture)));
    expect(collection.type).toBe("FeatureCollection");
    if (collection.type !== "FeatureCollection") throw new Error("Invalid fixture");
    expect(collection.features).toHaveLength(2);
    const [country, state] = collection.features;
    expect(country.properties).toEqual({ id: "42", name: "Île précise", kind: "country" });
    expect(country.geometry).toEqual({
      type: "Polygon",
      coordinates: [[[1.000001, 1.000002], [5, 1.000002], [5, 5], [1.000001, 5], [1.000001, 1.000002]]],
    });
    expect(state.properties).toEqual({ id: "43", name: "Islands", kind: "state", parent: "42" });
    expect(state.geometry).toEqual({
      type: "MultiPolygon",
      coordinates: [
        [[[10, 0], [20, 0], [20, 10], [10, 10], [10, 0]], [[12, 2], [14, 2], [14, 4], [12, 4], [12, 2]]],
        [[[30, 0], [32, 0], [32, 2], [30, 2], [30, 0]]],
      ],
    });
  });
});
