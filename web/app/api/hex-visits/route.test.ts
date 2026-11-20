import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("@/lib/auth", () => ({ auth: { api: { getSession: vi.fn() } } }));
vi.mock("@/lib/db", () => ({ db: { select: vi.fn() } }));

import { eq } from "drizzle-orm";
import { hexVisit } from "@/db/schema";
import { auth } from "@/lib/auth";
import { db } from "@/lib/db";
import { GET } from "./route";

const orderBy = vi.fn();
const groupBy = vi.fn(() => ({ orderBy }));
const where = vi.fn(() => ({ groupBy }));
const innerJoin = vi.fn(() => ({ where }));
const from = vi.fn(() => ({ innerJoin }));
const request = () => new Request("http://test/api/hex-visits?userId=someone-else");

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(auth.api.getSession).mockResolvedValue({ user: { id: "u1" }, session: {} } as never);
  vi.mocked(db.select).mockReturnValue({ from } as never);
  orderBy.mockResolvedValue([]);
});

describe("GET /api/hex-visits", () => {
  it("requires authentication before querying visits", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValueOnce(null);
    expect((await GET(request())).status).toBe(401);
    expect(db.select).not.toHaveBeenCalled();
  });

  it("returns totals and the user visit for every cell visited by the session user", async () => {
    orderBy.mockResolvedValueOnce([
      { cell: "8a2830828007fff", lastVisit: new Date("2026-11-20T10:00:00Z"), total: 42, score: "12.5", lastScore: "0.5", totalVisits: "105", rivalScore: "30.25" },
      { cell: "8a283082876ffff", lastVisit: new Date("2026-11-19T10:00:00Z"), total: 3, score: "2", lastScore: "1", totalVisits: "3", rivalScore: null },
    ]);
    const response = await GET(request());
    expect(response.status).toBe(200);
    expect(where).toHaveBeenCalledWith(eq(hexVisit.userId, "u1"));
    expect(response.headers.get("cache-control")).toBe("private, no-store");
    expect(await response.json()).toEqual({ visits: [
      { totals: { totalVisits: 105, rivalScore: 30.25 }, userVisit: { cell: "8a2830828007fff", lastVisit: "2026-11-20T10:00:00.000Z", total: 42, score: 12.5, lastScore: 0.5 } },
      { totals: { totalVisits: 3, rivalScore: 0 }, userVisit: { cell: "8a283082876ffff", lastVisit: "2026-11-19T10:00:00.000Z", total: 3, score: 2, lastScore: 1 } },
    ] });
  });

  it("returns an empty collection for a new user", async () => {
    expect(await (await GET(request())).json()).toEqual({ visits: [] });
  });

  it("does not expose database errors", async () => {
    const logger = vi.spyOn(console, "error").mockImplementation(() => {});
    try {
      orderBy.mockRejectedValueOnce(new Error("private SQL details"));
      const response = await GET(request());
      expect(response.status).toBe(500);
      expect(await response.json()).toEqual({ error: "Unable to download visits" });
      expect(logger).toHaveBeenCalledWith("Visit download failed", undefined);
    } finally {
      logger.mockRestore();
    }
  });
});
