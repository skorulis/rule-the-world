import { beforeEach, describe, expect, it, vi } from "vitest";
import { PgDialect } from "drizzle-orm/pg-core";

vi.mock("@/lib/auth", () => ({ auth: { api: { getSession: vi.fn() } } }));
vi.mock("@/lib/db", () => ({ db: { execute: vi.fn() } }));

import { auth } from "@/lib/auth";
import { db } from "@/lib/db";
import { POST } from "./route";

const user = { id: "u1", name: "Alex", email: "a@b.c" };
const request = () => new Request("http://test/api/debug/cheat/add_money");

beforeEach(() => {
  vi.clearAllMocks();
  vi.stubEnv("NODE_ENV", "development");
  vi.mocked(auth.api.getSession).mockResolvedValue({ user, session: {} } as never);
  vi.mocked(db.execute).mockResolvedValue([{ coins: 1500 }] as never);
});

describe("POST /api/debug/cheat/add_money", () => {
  it("returns 404 outside development", async () => {
    vi.stubEnv("NODE_ENV", "production");
    expect((await POST(request())).status).toBe(404);
    expect(db.execute).not.toHaveBeenCalled();
  });

  it("requires authentication", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValueOnce(null);
    expect((await POST(request())).status).toBe(401);
    expect(db.execute).not.toHaveBeenCalled();
  });

  it("adds 1000 coins and returns the new balance", async () => {
    const response = await POST(request());
    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("private, no-store");
    expect(await response.json()).toEqual({ added: 1000, coins: 1500 });
  });

  it("scopes the credit to the session user", async () => {
    await POST(request());
    const statement = vi.mocked(db.execute).mock.calls[0][0];
    if (typeof statement === "string") throw new Error("Expected parameterized SQL");
    const query = new PgDialect().sqlToQuery(statement.getSQL());
    expect(query.params).toContain("u1");
    expect(query.params).toContain(1000);
    expect(query.sql).toContain('update "user"');
    expect(query.sql).toContain('"total_earnings"');
    expect(query.sql).toContain('where "user"."id" =');
    expect(query.sql).toContain("returning");
  });

  it("sanitizes database failures", async () => {
    const logger = vi.spyOn(console, "error").mockImplementation(() => {});
    try {
      vi.mocked(db.execute).mockRejectedValueOnce(new Error("private SQL"));
      const response = await POST(request());
      expect(response.status).toBe(500);
      expect(await response.json()).toEqual({ error: "Unable to add coins" });
    } finally {
      logger.mockRestore();
    }
  });
});
