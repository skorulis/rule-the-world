import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("@/lib/auth", () => ({ auth: { api: { getSession: vi.fn() } } }));
vi.mock("@/lib/db", () => ({ db: { select: vi.fn() } }));

import { inArray } from "drizzle-orm";
import { hexVisit } from "@/db/schema";
import { auth } from "@/lib/auth";
import { db } from "@/lib/db";
import { isVisitCell } from "@/lib/visits/visit-batch";
import { GET } from "./route";

const groupBy = vi.fn();
const where = vi.fn();
const from = vi.fn(() => ({ where }));
const cell = "8a2830828007fff";
const otherCell = "8a283082876ffff";
const cellId = BigInt(`0x${cell}`);
const request = (cells = cell) => new Request(`http://test/api/hex-visits/info?cells=${cells}`);

const visitRow = {
  cell: cellId,
  lastVisit: new Date("2026-11-20T10:00:00Z"),
  total: 42,
  score: "12.5",
  lastScore: "0.5",
};

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(auth.api.getSession).mockResolvedValue({ user: { id: "u1" }, session: {} } as never);
  vi.mocked(db.select).mockReturnValue({ from } as never);
  groupBy.mockResolvedValue([]);
  where.mockImplementation(() => Object.assign(Promise.resolve([]), { groupBy }));
});

describe("GET /api/hex-visits/info", () => {
  it("requires authentication before querying visits", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValueOnce(null);
    expect((await GET(request())).status).toBe(401);
    expect(db.select).not.toHaveBeenCalled();
  });

  it("rejects a missing cells parameter without querying", async () => {
    const response = await GET(new Request("http://test/api/hex-visits/info"));
    expect(response.status).toBe(400);
    expect(db.select).not.toHaveBeenCalled();
  });

  it("rejects an invalid cell without querying", async () => {
    const response = await GET(request(`${cell},nope`));
    expect(response.status).toBe(400);
    expect(db.select).not.toHaveBeenCalled();
  });

  it("rejects more than 500 cells without querying", async () => {
    const cells = Array.from({ length: 5000 }, (_, i) => `8a283082${i.toString(16).padStart(4, "0")}fff`)
      .filter(isVisitCell).slice(0, 501);
    expect(cells).toHaveLength(501);
    const response = await GET(request(cells.join(",")));
    expect(response.status).toBe(400);
    expect(db.select).not.toHaveBeenCalled();
  });

  it("returns totals and user visits for each requested cell", async () => {
    groupBy.mockResolvedValue([{ cell: cellId, totalVisits: "105", rivalScore: "30.25" }]);
    where.mockImplementation(() => Object.assign(Promise.resolve([visitRow]), { groupBy }));
    const response = await GET(request(`${cell},${otherCell}`));
    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("private, no-store");
    expect(await response.json()).toEqual({
      visits: [
        {
          cell,
          totals: { totalVisits: 105, rivalScore: 30.25 },
          userVisit: {
            cell,
            lastVisit: "2026-11-20T10:00:00.000Z",
            total: 42,
            score: 12.5,
            lastScore: 0.5,
          },
        },
        { cell: otherCell, totals: null, userVisit: null },
      ],
    });
  });

  it("excludes the session user from the rival score", async () => {
    await GET(request());
    expect(where).toHaveBeenCalledWith(inArray(hexVisit.cell, [cellId]));
  });

  it("deduplicates repeated cells", async () => {
    const response = await GET(request(`${cell},${cell}`));
    const body = await response.json();
    expect(body.visits).toHaveLength(1);
    expect(where).toHaveBeenCalledWith(inArray(hexVisit.cell, [cellId]));
  });

  it("returns a null userVisit when only rivals have visited", async () => {
    groupBy.mockResolvedValue([{ cell: cellId, totalVisits: "7", rivalScore: "9" }]);
    expect(await (await GET(request())).json()).toEqual({
      visits: [{ cell, totals: { totalVisits: 7, rivalScore: 9 }, userVisit: null }],
    });
  });

  it("does not expose database errors", async () => {
    const logger = vi.spyOn(console, "error").mockImplementation(() => {});
    try {
      where.mockImplementation(() => Object.assign(Promise.reject(new Error("private SQL details")), { groupBy }));
      const response = await GET(request());
      expect(response.status).toBe(500);
      expect(await response.json()).toEqual({ error: "Unable to load hexagons" });
      expect(logger).toHaveBeenCalledWith("Hex info lookup failed", undefined);
    } finally {
      logger.mockRestore();
    }
  });
});
