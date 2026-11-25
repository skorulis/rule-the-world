import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("@/lib/auth", () => ({ auth: { api: { getSession: vi.fn() } } }));
vi.mock("@/lib/db", () => ({ db: { execute: vi.fn() } }));

import { auth } from "@/lib/auth";
import { db } from "@/lib/db";
import { GET } from "./route";

const request = (query = "?type=country&id=123") =>
  new Request(`http://test/api/regions/leaders${query}`);

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(auth.api.getSession).mockResolvedValue({ user: { id: "u1" }, session: {} } as never);
  vi.mocked(db.execute).mockResolvedValue([] as never);
});

describe("GET /api/regions/leaders", () => {
  it("requires authentication before querying leaders", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValueOnce(null);
    expect((await GET(request())).status).toBe(401);
    expect(db.execute).not.toHaveBeenCalled();
  });

  it("rejects a missing or unsupported region type", async () => {
    expect((await GET(request("?id=123"))).status).toBe(400);
    expect((await GET(request("?type=global&id=123"))).status).toBe(400);
    expect((await GET(request("?type=planet&id=123"))).status).toBe(400);
    expect(db.execute).not.toHaveBeenCalled();
  });

  it("rejects a missing or invalid region id", async () => {
    expect((await GET(request("?type=country"))).status).toBe(400);
    expect((await GET(request("?type=country&id=0"))).status).toBe(400);
    expect((await GET(request("?type=country&id=-3"))).status).toBe(400);
    expect((await GET(request("?type=country&id=abc"))).status).toBe(400);
    expect(db.execute).not.toHaveBeenCalled();
  });

  it("returns the names of users holding the top three ranks", async () => {
    vi.mocked(db.execute).mockResolvedValueOnce([
      { rank: 1, name: "Alice" },
      { rank: 2, name: "Bob" },
      { rank: 3, name: "Carol" },
    ] as never);
    const response = await GET(request());
    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("private, no-store");
    expect(await response.json()).toEqual({ leaders: [
      { rank: 1, name: "Alice" },
      { rank: 2, name: "Bob" },
      { rank: 3, name: "Carol" },
    ] });
  });

  it("returns an empty collection when nobody holds a top rank", async () => {
    expect(await (await GET(request("?type=state&id=5"))).json()).toEqual({ leaders: [] });
  });

  it("does not expose database errors", async () => {
    const logger = vi.spyOn(console, "error").mockImplementation(() => {});
    try {
      vi.mocked(db.execute).mockRejectedValueOnce(new Error("private SQL details"));
      const response = await GET(request());
      expect(response.status).toBe(500);
      expect(await response.json()).toEqual({ error: "Unable to load region leaders" });
    } finally {
      logger.mockRestore();
    }
  });
});
