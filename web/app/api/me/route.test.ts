import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { PgDialect } from "drizzle-orm/pg-core";

vi.mock("@/lib/auth", () => ({ auth: { api: { getSession: vi.fn() } } }));
vi.mock("@/lib/db", () => ({ db: { execute: vi.fn() } }));

import { auth } from "@/lib/auth";
import { db } from "@/lib/db";
import { GET } from "./route";

const user = { id: "u1", name: "Alex", email: "a@b.c", createdAt: new Date("2026-01-02T03:04:05.000Z") };
const request = () => new Request("http://test/api/me?userId=someone-else");

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(auth.api.getSession).mockResolvedValue({ user, session: {} } as never);
  vi.mocked(db.execute).mockResolvedValue([] as never);
});

describe("GET /api/me", () => {
  it("requires authentication before querying", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValueOnce(null);
    expect((await GET(request())).status).toBe(401);
    expect(db.execute).not.toHaveBeenCalled();
  });

  it("preserves user data and returns overall and regional counts", async () => {
    vi.mocked(db.execute).mockResolvedValueOnce([
      { region: "1234", kind: 1, overall: 0, visited: "10", owned: "5" },
      { region: "2345", kind: 1, overall: 0, visited: "4", owned: "0" },
      { region: "3456", kind: 2, overall: 0, visited: "6", owned: "2" },
      { region: "4567", kind: 3, overall: 0, visited: "3", owned: "1" },
      { region: null, kind: null, overall: 1, visited: "20", owned: "8" },
    ] as never);
    const response = await GET(request());
    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("private, no-store");
    expect(await response.json()).toEqual({
      user: { ...user, createdAt: user.createdAt.toISOString() },
      visited: 20, owned: 8,
      powerups: {},
      rankings: [],
      dailyRewardAvailableAt: expect.any(String),
      regions: [
        { id: 1234, kind: "country", visited: 10, owned: 5 },
        { id: 2345, kind: "country", visited: 4, owned: 0 },
        { id: 3456, kind: "state", visited: 6, owned: 2 },
        { id: 4567, kind: "suburb", visited: 3, owned: 1 },
      ],
    });
  });

  it("returns zero totals for a new user", async () => {
    const body = await (await GET(request())).json();
    expect(body).toMatchObject({ visited: 0, owned: 0, regions: [], powerups: {} });
  });

  it("returns the user's power-up inventory", async () => {
    vi.mocked(db.execute)
      .mockResolvedValueOnce([{ region: null, kind: null, overall: 1, visited: "2", owned: "1" }] as never)
      .mockResolvedValueOnce([{ powerups: { "1": 3 } }] as never);
    const body = await (await GET(request())).json();
    expect(body.powerups).toEqual({ "1": 3 });
  });

  it("treats a missing powerups column value as an empty inventory", async () => {
    vi.mocked(db.execute)
      .mockResolvedValueOnce([] as never)
      .mockResolvedValueOnce([{ powerups: null }] as never);
    const body = await (await GET(request())).json();
    expect(body.powerups).toEqual({});
  });

  it("returns the user's stored rankings", async () => {
    vi.mocked(db.execute)
      .mockResolvedValueOnce([] as never)
      .mockResolvedValueOnce([{ powerups: {}, rankings: [{ id: 1159320379, type: "country", number: 15, visited: 6, owned: 2 }] }] as never);
    const body = await (await GET(request())).json();
    expect(body.rankings).toEqual([{ id: 1159320379, type: "country", number: 15, visited: 6, owned: 2 }]);
    const statement = vi.mocked(db.execute).mock.calls[1][0];
    if (typeof statement === "string") throw new Error("Expected parameterized SQL");
    expect(new PgDialect().sqlToQuery(statement.getSQL()).sql).toContain('"user"."rankings" as rankings');
  });

  it("treats a missing rankings column value as no rankings", async () => {
    vi.mocked(db.execute)
      .mockResolvedValueOnce([] as never)
      .mockResolvedValueOnce([{ powerups: {}, rankings: null }] as never);
    expect((await (await GET(request())).json()).rankings).toEqual([]);
  });

  describe("dailyRewardAvailableAt", () => {
    const now = new Date("2026-11-23T15:30:00.000Z");

    beforeEach(() => {
      vi.useFakeTimers({ toFake: ["Date"] });
      vi.setSystemTime(now);
    });

    afterEach(() => {
      vi.useRealTimers();
    });

    it("is now when the reward has never been claimed", async () => {
      const body = await (await GET(request())).json();
      expect(body.dailyRewardAvailableAt).toBe(now.toISOString());
    });

    it("is now when the reward was last claimed on an earlier UTC day", async () => {
      vi.mocked(db.execute)
        .mockResolvedValueOnce([] as never)
        .mockResolvedValueOnce([{ powerups: {}, daily_reward_day: "2026-11-22" }] as never);
      const body = await (await GET(request())).json();
      expect(body.dailyRewardAvailableAt).toBe(now.toISOString());
    });

    it("is the next UTC midnight when the reward was claimed today", async () => {
      vi.mocked(db.execute)
        .mockResolvedValueOnce([] as never)
        .mockResolvedValueOnce([{ powerups: {}, daily_reward_day: "2026-11-23" }] as never);
      const body = await (await GET(request())).json();
      expect(body.dailyRewardAvailableAt).toBe("2026-11-24T00:00:00.000Z");
    });

    it("selects the claim day as text for the session user", async () => {
      await GET(request());
      const statement = vi.mocked(db.execute).mock.calls[1][0];
      if (typeof statement === "string") throw new Error("Expected parameterized SQL");
      const query = new PgDialect().sqlToQuery(statement.getSQL());
      expect(query.sql).toContain('"user"."daily_reward_day"::text as daily_reward_day');
      expect(query.params).toEqual(["u1"]);
    });
  });

  it("drops invalid and unsafe region IDs without losing overall counts", async () => {
    vi.mocked(db.execute).mockResolvedValueOnce([
      { region: null, kind: null, overall: 1, visited: "3", owned: "1" },
      ...[null, "0", "-1", "9007199254740993"].map((region) => ({ region, kind: 1, overall: 0, visited: "1", owned: "0" })),
      { region: "42", kind: 9, overall: 0, visited: "2", owned: "1" },
    ] as never);
    expect(await (await GET(request())).json()).toMatchObject({ visited: 3, owned: 1, regions: [] });
  });

  it("scopes distinct cells to the session and compares numeric scores strictly before aggregating", async () => {
    await GET(request());
    const statement = vi.mocked(db.execute).mock.calls[0][0];
    if (typeof statement === "string") throw new Error("Expected parameterized SQL");
    const query = new PgDialect().sqlToQuery(statement.getSQL());
    expect(query.params).toEqual(["u1", "u1"]);
    expect(query.sql).toContain('where "hex_visit"."user_id" =');
    expect(query.sql).toContain('"hex_visit"."score" > coalesce');
    expect(query.sql).toContain('select max(rival.score)');
    expect(query.sql).toContain('rival.cell = "hex_visit"."cell" and rival.user_id <>');
    expect(query.sql).toContain('join "hex_details"');
    expect(query.sql).toContain('count(*) filter (where owned)');
    expect(query.sql).toContain('cross join lateral (values');
    expect(query.sql).toContain('("hex_details"."region_country", 1)');
    expect(query.sql).toContain('("hex_details"."region_state", 2)');
    expect(query.sql).toContain('("hex_details"."region_suburb", 3)');
    expect(query.sql).toContain('where membership.region is not null');
    expect(query.sql).toContain('group by membership.region, membership.kind');
    expect(query.sql).toContain('union all');
    expect(query.sql).toContain('from user_cells');
  });

  it("sanitizes database failures", async () => {
    const logger = vi.spyOn(console, "error").mockImplementation(() => {});
    try {
      vi.mocked(db.execute).mockRejectedValueOnce(new Error("private SQL"));
      const response = await GET(request());
      expect(response.status).toBe(500);
      expect(await response.json()).toEqual({ error: "Unable to load profile" });
    } finally {
      logger.mockRestore();
    }
  });
});
