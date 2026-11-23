import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { PgDialect } from "drizzle-orm/pg-core";

vi.mock("@/lib/auth", () => ({ auth: { api: { getSession: vi.fn() } } }));
vi.mock("@/lib/db", () => ({ db: { execute: vi.fn() } }));

import { auth } from "@/lib/auth";
import { db } from "@/lib/db";
import { powerUpDefinitions } from "@/lib/powerups/powerups";
import { POST } from "./route";

const user = { id: "u1", name: "Alex", email: "a@b.c" };
const request = () => new Request("http://test/api/powerup/daily", { method: "POST" });

beforeEach(() => {
  vi.clearAllMocks();
  vi.useFakeTimers({ toFake: ["Date"] });
  vi.setSystemTime(new Date("2026-11-23T15:30:00.000Z"));
  vi.mocked(auth.api.getSession).mockResolvedValue({ user, session: {} } as never);
  vi.mocked(db.execute).mockResolvedValue([{ powerups: { "1": 2 } }] as never);
});

afterEach(() => {
  vi.useRealTimers();
});

describe("POST /api/powerup/daily", () => {
  it("requires authentication", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValueOnce(null);
    expect((await POST(request())).status).toBe(401);
    expect(db.execute).not.toHaveBeenCalled();
  });

  it("grants a common power-up and returns the updated inventory", async () => {
    const response = await POST(request());
    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("private, no-store");
    const body = await response.json();
    expect(powerUpDefinitions).toContainEqual(body.powerup);
    expect(body.powerup.rarity).toBe("common");
    expect(body.powerups).toEqual({ "1": 2 });
  });

  it("only ever grants common power-ups", async () => {
    const random = vi.spyOn(Math, "random");
    try {
      for (const value of [0, 0.25, 0.5, 0.75, 0.999]) {
        random.mockReturnValue(value);
        const body = await (await POST(request())).json();
        expect(body.powerup.rarity).toBe("common");
      }
    } finally {
      random.mockRestore();
    }
  });

  it("increments once, stamps today's UTC day and guards against a second claim", async () => {
    await POST(request());
    const statement = vi.mocked(db.execute).mock.calls[0][0];
    if (typeof statement === "string") throw new Error("Expected parameterized SQL");
    const query = new PgDialect().sqlToQuery(statement.getSQL());
    expect(query.params).toContain("u1");
    expect(query.params).toContain("2026-11-23");
    expect(query.sql).toContain('update "user"');
    expect(query.sql).toContain("jsonb_set");
    expect(query.sql).toContain("+ 1");
    expect(query.sql).toMatch(/"daily_reward_day" = \$\d+::date/);
    expect(query.sql).toContain('where "user"."id" =');
    expect(query.sql).toMatch(/"user"."daily_reward_day" is null or "user"."daily_reward_day" < \$\d+::date/);
    expect(query.sql).toContain("returning");
  });

  it("rejects a second claim on the same UTC day", async () => {
    vi.mocked(db.execute).mockResolvedValueOnce([] as never);
    const response = await POST(request());
    expect(response.status).toBe(409);
    expect(await response.json()).toEqual({ error: "Daily reward already claimed" });
  });

  it("sanitizes database failures", async () => {
    const logger = vi.spyOn(console, "error").mockImplementation(() => {});
    try {
      vi.mocked(db.execute).mockRejectedValueOnce(new Error("private SQL"));
      const response = await POST(request());
      expect(response.status).toBe(500);
      expect(await response.json()).toEqual({ error: "Unable to claim daily reward" });
    } finally {
      logger.mockRestore();
    }
  });
});
