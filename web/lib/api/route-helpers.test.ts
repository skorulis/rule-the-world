import { describe, expect, it } from "vitest";
import { jsonError, parsePositiveId } from "./route-helpers";

describe("jsonError", () => {
  it("returns the given status and error body", async () => {
    const res = jsonError("Nope", 403);
    expect(res.status).toBe(403);
    expect(await res.json()).toEqual({ error: "Nope" });
  });
});

describe("parsePositiveId", () => {
  it.each([
    [5, 5],
    ["5", 5],
    ["0", null],
    [0, null],
    ["abc", null],
    [1.5, null],
    [-3, null],
    ["", null],
    [undefined, null],
  ])("parsePositiveId(%j) -> %j", (input, expected) => {
    expect(parsePositiveId(input)).toBe(expected);
  });
});
