import { beforeEach, describe, expect, it, vi } from "vitest";
import { PgDialect } from "drizzle-orm/pg-core";

vi.mock("@/lib/auth", () => ({ auth: { api: { getSession: vi.fn() } } }));
vi.mock("@/lib/db", () => ({ db: { execute: vi.fn() } }));

import { auth } from "@/lib/auth";
import { db } from "@/lib/db";
import { lootBoxDefinitions } from "@/lib/lootboxes";
import { POST } from "./route";

const user = { id: "u1", name: "Alex", email: "a@b.c" };
const commonBox = lootBoxDefinitions.find((def) => def.rarity === "common");
if (!commonBox) throw new Error("Expected a common loot box in lootboxes.json");

const request = (body: unknown) => new Request("http://test/api/shop", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify(body),
});

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(auth.api.getSession).mockResolvedValue({ user, session: {} } as never);
  vi.mocked(db.execute).mockResolvedValue([{ coins: 40, powerups: { "1": 2 } }] as never);
});

describe("POST /api/shop", () => {
  it("requires authentication", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValueOnce(null);
    expect((await POST(request({ box: commonBox.id, count: 1 }))).status).toBe(401);
    expect(db.execute).not.toHaveBeenCalled();
  });

  it("rejects invalid bodies", async () => {
    for (const body of [
      {},
      { box: "abc", count: 1 },
      { box: -1, count: 1 },
      { box: 9999, count: 1 },
      { box: commonBox.id },
      { box: commonBox.id, count: 0 },
      { box: commonBox.id, count: 11 },
      { box: commonBox.id, count: 1.5 },
    ]) {
      const response = await POST(request(body));
      expect([400, 404]).toContain(response.status);
    }
    expect(db.execute).not.toHaveBeenCalled();
  });

  it("grants one power-up of the box rarity and returns the new balance", async () => {
    const response = await POST(request({ box: commonBox.id, count: 1 }));
    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("private, no-store");
    const body = await response.json();
    expect(body.rewards).toHaveLength(1);
    expect(body.rewards[0].rarity).toBe("common");
    expect(body.powerups).toEqual({ "1": 2 });
    expect(body.coins).toBe(40);
  });

  it("grants one power-up per box when buying multiple", async () => {
    const body = await (await POST(request({ box: commonBox.id, count: 5 }))).json();
    expect(body.rewards).toHaveLength(5);
    for (const reward of body.rewards) {
      expect(reward.rarity).toBe("common");
    }
    const statement = vi.mocked(db.execute).mock.calls[0][0];
    if (typeof statement === "string") throw new Error("Expected parameterized SQL");
    const query = new PgDialect().sqlToQuery(statement.getSQL());
    expect(query.params).toContain(commonBox.cost * 5);
  });

  it("debits coins atomically and guards against insufficient funds", async () => {
    await POST(request({ box: commonBox.id, count: 1 }));
    const statement = vi.mocked(db.execute).mock.calls[0][0];
    if (typeof statement === "string") throw new Error("Expected parameterized SQL");
    const query = new PgDialect().sqlToQuery(statement.getSQL());
    expect(query.params).toContain("u1");
    expect(query.params).toContain(commonBox.cost);
    expect(query.sql).toContain('update "user"');
    expect(query.sql).toMatch(/"coins" = coalesce\("user"\."coins", 0\) - \$\d+/);
    expect(query.sql).toMatch(/coalesce\("user"\."coins", 0\) >= \$\d+/);
    expect(query.sql).toContain("jsonb_object_agg");
    expect(query.sql).toContain("returning");
  });

  it("rejects when the update finds insufficient coins", async () => {
    vi.mocked(db.execute).mockResolvedValueOnce([] as never);
    const response = await POST(request({ box: commonBox.id, count: 1 }));
    expect(response.status).toBe(409);
    expect(await response.json()).toEqual({ error: "Not enough coins" });
  });

  it("sanitizes database failures", async () => {
    const logger = vi.spyOn(console, "error").mockImplementation(() => {});
    try {
      vi.mocked(db.execute).mockRejectedValueOnce(new Error("private SQL"));
      const response = await POST(request({ box: commonBox.id, count: 1 }));
      expect(response.status).toBe(500);
      expect(await response.json()).toEqual({ error: "Unable to purchase loot box" });
    } finally {
      logger.mockRestore();
    }
  });
});
