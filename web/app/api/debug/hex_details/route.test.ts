import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("@/lib/auth", () => ({ auth: { api: { getSession: vi.fn() } } }));
vi.mock("@/lib/regions/hex-details", () => ({ getOrCreateHexDetails: vi.fn() }));
vi.mock("h3-js", () => ({ latLngToCell: vi.fn(() => "8a2830828007fff") }));

import { latLngToCell } from "h3-js";
import { auth } from "@/lib/auth";
import { getOrCreateHexDetails } from "@/lib/regions/hex-details";
import { GET } from "./route";

const cell = BigInt("0x8a2830828007fff");

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(auth.api.getSession).mockResolvedValue({ user: { id: "u1" }, session: {} } as never);
  vi.mocked(getOrCreateHexDetails).mockResolvedValue({ cell, regionCountry: BigInt(42), regionState: BigInt(7) });
});

afterEach(() => vi.restoreAllMocks());

describe("GET /api/debug/hex_details", () => {
  it("classifies a hex without a session or authentication lookup", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValueOnce(null);
    expect((await GET()).status).toBe(200);
    expect(auth.api.getSession).not.toHaveBeenCalled();
    expect(getOrCreateHexDetails).toHaveBeenCalledWith(cell);
  });

  it("chooses a random resolution-10 hex and returns JSON-safe details without caching", async () => {
    vi.spyOn(Math, "random").mockReturnValueOnce(0.5).mockReturnValueOnce(0.75);
    const response = await GET();
    expect(latLngToCell).toHaveBeenCalledWith(0, 90, 10);
    expect(getOrCreateHexDetails).toHaveBeenCalledWith(cell);
    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("private, no-store");
    expect(await response.json()).toEqual({
      cell: "8a2830828007fff", region_country: "42", region_state: "7",
    });
  });

  it("preserves null region mappings for ocean cells", async () => {
    vi.mocked(getOrCreateHexDetails).mockResolvedValueOnce({ cell, regionCountry: null, regionState: null });
    expect(await (await GET()).json()).toEqual({
      cell: "8a2830828007fff", region_country: null, region_state: null,
    });
  });

  it("sanitizes classification and database failures", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    vi.mocked(getOrCreateHexDetails).mockRejectedValueOnce(new Error("private SQL"));
    const response = await GET();
    expect(response.status).toBe(500);
    expect(await response.json()).toEqual({ error: "Unable to load hex details" });
  });
});
