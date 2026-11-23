import { beforeEach, describe, expect, it, vi } from "vitest";
import { PgDialect } from "drizzle-orm/pg-core";

vi.mock("@/lib/auth", () => ({ auth: { api: { getSession: vi.fn() } } }));
vi.mock("@/lib/db", () => ({ db: { execute: vi.fn() } }));

import { auth } from "@/lib/auth";
import { db } from "@/lib/db";
import { powerUpDefinitions } from "@/lib/powerups/powerups";
import { POST } from "./route";

const user = { id: "u1", name: "Alex", email: "a@b.c" };
const request = () => new Request("http://test/api/debug/add_powerup");

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(auth.api.getSession).mockResolvedValue({ user, session: {} } as never);
  vi.mocked(db.execute).mockResolvedValue([{ powerups: { "1": 2 } }] as never);
});

describe("POST /api/debug/add_powerup", () => {
  it("requires authentication", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValueOnce(null);
    expect((await POST(request())).status).toBe(401);
    expect(db.execute).not.toHaveBeenCalled();
  });

  it("grants a defined power-up and returns the updated inventory", async () => {
    const response = await POST(request());
    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("private, no-store");
    const body = await response.json();
    expect(powerUpDefinitions).toContainEqual(body.powerup);
    expect(body.powerups).toEqual({ "1": 2 });
  });

  it("scopes the increment to the session user and grants exactly one", async () => {
    await POST(request());
    const statement = vi.mocked(db.execute).mock.calls[0][0];
    if (typeof statement === "string") throw new Error("Expected parameterized SQL");
    const query = new PgDialect().sqlToQuery(statement.getSQL());
    expect(query.params).toContain("u1");
    expect(query.sql).toContain('update "user"');
    expect(query.sql).toContain("jsonb_set");
    expect(query.sql).toContain("+ 1");
    expect(query.sql).toContain('where "user"."id" =');
    expect(query.sql).toContain("returning");
  });

  it("sanitizes database failures", async () => {
    const logger = vi.spyOn(console, "error").mockImplementation(() => {});
    try {
      vi.mocked(db.execute).mockRejectedValueOnce(new Error("private SQL"));
      const response = await POST(request());
      expect(response.status).toBe(500);
      expect(await response.json()).toEqual({ error: "Unable to add power-up" });
    } finally {
      logger.mockRestore();
    }
  });
});
