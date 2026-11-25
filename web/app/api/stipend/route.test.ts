import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { PgDialect } from "drizzle-orm/pg-core";

vi.mock("@/lib/auth", () => ({ auth: { api: { getSession: vi.fn() } } }));
vi.mock("@/lib/db", () => ({ db: { execute: vi.fn() } }));

import { auth } from "@/lib/auth";
import { db } from "@/lib/db";
import type { RegionRanking } from "@/db/auth-schema";
import { dailyStipend } from "@/lib/stipend";
import { POST } from "./route";

const request = () => new Request("http://test/api/stipend?userId=someone-else", { method: "POST" });
const query = (index: number) => {
  const statement = vi.mocked(db.execute).mock.calls[index][0];
  if (typeof statement === "string") throw new Error("Expected parameterized SQL");
  return new PgDialect().sqlToQuery(statement.getSQL());
};

beforeEach(() => {
  vi.resetAllMocks();
  vi.useFakeTimers({ toFake: ["Date"] });
  vi.setSystemTime(new Date("2026-11-25T12:00:00Z"));
  vi.mocked(auth.api.getSession).mockResolvedValue({ user: { id: "u1" }, session: {} } as never);
  vi.mocked(db.execute).mockResolvedValue([] as never);
});

afterEach(() => vi.useRealTimers());

describe("POST /api/stipend", () => {
  it("requires authentication before querying", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValueOnce(null);
    expect((await POST(request())).status).toBe(401);
    expect(db.execute).not.toHaveBeenCalled();
  });

  it("reads normalized rankings and returns the same title-inclusive stipend", async () => {
    const rankings: RegionRanking[] = [
      { id: 1, type: "global", number: 1, visited: 12000, owned: 11000 },
      { id: 1, type: "country", number: 1, visited: 6000, owned: 5500 },
      { id: 1, type: "suburb", number: 1, visited: 20, owned: 20 },
    ];
    const stipend = dailyStipend(rankings);
    vi.mocked(db.execute).mockResolvedValueOnce([{ rankings, stipend_day: "2026-11-24" }] as never)
      .mockResolvedValueOnce([{ coins: stipend + 100 }] as never);
    const response = await POST(request());
    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("private, no-store");
    expect(await response.json()).toEqual({ stipend, coins: stipend + 100 });
    expect(stipend).toBeGreaterThan(10);
    const read = query(0);
    expect(read.sql).toContain('from "player_ranking"');
    expect(read.sql).toContain('where "player_ranking"."user_id" = "user"."id"');
    expect(read.sql).not.toContain('"user"."rankings"');
    expect(read.params).toEqual(["u1"]);
    const update = query(1);
    expect(update.sql).toContain('"total_earnings" = coalesce("user"."total_earnings", 0) +');
    expect(update.sql).toContain('where "user"."id" =');
    expect(update.sql).toContain('("user"."stipend_day" is null or "user"."stipend_day" <');
    expect(update.params).toEqual([stipend, stipend, "2026-11-25", "u1", "2026-11-25"]);
  });

  it("pays the base stipend when there are no ranking rows", async () => {
    vi.mocked(db.execute).mockResolvedValueOnce([{ rankings: [], stipend_day: null }] as never)
      .mockResolvedValueOnce([{ coins: 10 }] as never);
    expect(await (await POST(request())).json()).toEqual({ stipend: 10, coins: 10 });
  });

  it("rejects an already collected stipend before updating", async () => {
    vi.mocked(db.execute).mockResolvedValueOnce([{ rankings: [], stipend_day: "2026-11-25" }] as never);
    const response = await POST(request());
    expect(response.status).toBe(409);
    expect(await response.json()).toEqual({ error: "Stipend already collected" });
    expect(db.execute).toHaveBeenCalledTimes(1);
  });

  it("rejects a concurrent collection when the guarded update returns no row", async () => {
    vi.mocked(db.execute).mockResolvedValueOnce([{ rankings: [], stipend_day: null }] as never);
    expect((await POST(request())).status).toBe(409);
    expect(db.execute).toHaveBeenCalledTimes(2);
  });

  it("sanitizes database failures", async () => {
    const logger = vi.spyOn(console, "error").mockImplementation(() => {});
    try {
      vi.mocked(db.execute).mockRejectedValueOnce(new Error("private SQL"));
      const response = await POST(request());
      expect(response.status).toBe(500);
      expect(await response.json()).toEqual({ error: "Unable to collect stipend" });
    } finally {
      logger.mockRestore();
    }
  });
});
