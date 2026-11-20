import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("@/lib/auth", () => ({ auth: { api: { getSession: vi.fn() } } }));
vi.mock("@/lib/db", () => ({ db: { select: vi.fn() } }));

import { and, eq, ne } from "drizzle-orm";
import { hexVisit } from "@/db/schema";
import { auth } from "@/lib/auth";
import { db } from "@/lib/db";
import { GET } from "./route";

const where = vi.fn();
const from = vi.fn(() => ({ where }));
const cell = "8a2830828007fff";
const request = () => new Request(`http://test/api/hex-visits/${cell}`);
const ctx = { params: Promise.resolve({ cell }) };

const visitRow = {
  cell,
  lastVisit: new Date("2026-11-20T10:00:00Z"),
  total: 42,
  score: "12.5",
  lastScore: "0.5",
};

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(auth.api.getSession).mockResolvedValue({ user: { id: "u1" }, session: {} } as never);
  vi.mocked(db.select).mockReturnValue({ from } as never);
  where
    .mockResolvedValueOnce([{ totalVisits: "0" }])
    .mockResolvedValueOnce([{ rivalScore: null }])
    .mockResolvedValueOnce([]);
});

describe("GET /api/hex-visits/[cell]", () => {
  it("requires authentication before querying visits", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValueOnce(null);
    expect((await GET(request(), ctx)).status).toBe(401);
    expect(db.select).not.toHaveBeenCalled();
  });

  it("returns totals and the user's visit for a visited hex", async () => {
    where.mockReset();
    where
      .mockResolvedValueOnce([{ totalVisits: "105" }])
      .mockResolvedValueOnce([{ rivalScore: "30.25" }])
      .mockResolvedValueOnce([visitRow]);
    const response = await GET(request(), ctx);
    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("private, no-store");
    expect(await response.json()).toEqual({
      totalVisits: 105,
      rivalScore: 30.25,
      userVisit: {
        cell,
        lastVisit: "2026-11-20T10:00:00.000Z",
        total: 42,
        score: 12.5,
        lastScore: 0.5,
      },
    });
  });

  it("excludes the session user from the rival score", async () => {
    where.mockReset();
    where
      .mockResolvedValueOnce([{ totalVisits: "42" }])
      .mockResolvedValueOnce([{ rivalScore: "30.25" }])
      .mockResolvedValueOnce([visitRow]);
    await GET(request(), ctx);
    expect(where).toHaveBeenCalledWith(
      and(eq(hexVisit.cell, cell), ne(hexVisit.userId, "u1")),
    );
  });

  it("returns a null userVisit when only rivals have visited", async () => {
    where.mockReset();
    where
      .mockResolvedValueOnce([{ totalVisits: "7" }])
      .mockResolvedValueOnce([{ rivalScore: "9" }])
      .mockResolvedValueOnce([]);
    expect(await (await GET(request(), ctx)).json()).toEqual({
      totalVisits: 7,
      rivalScore: 9,
      userVisit: null,
    });
  });

  it("returns zeroed totals for an unseen cell", async () => {
    where.mockReset();
    where
      .mockResolvedValueOnce([{ totalVisits: null }])
      .mockResolvedValueOnce([{ rivalScore: null }])
      .mockResolvedValueOnce([]);
    expect(await (await GET(request(), ctx)).json()).toEqual({
      totalVisits: 0,
      rivalScore: 0,
      userVisit: null,
    });
  });

  it("does not expose database errors", async () => {
    const logger = vi.spyOn(console, "error").mockImplementation(() => {});
    try {
      where.mockReset();
      where.mockRejectedValueOnce(new Error("private SQL details"));
      const response = await GET(request(), ctx);
      expect(response.status).toBe(500);
      expect(await response.json()).toEqual({ error: "Unable to load hexagon" });
      expect(logger).toHaveBeenCalledWith("Hex totals lookup failed", undefined);
    } finally {
      logger.mockRestore();
    }
  });
});
