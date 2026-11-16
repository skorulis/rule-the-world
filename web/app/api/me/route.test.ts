import { describe, expect, it, vi } from "vitest";

vi.mock("@/lib/auth", () => ({
  auth: { api: { getSession: vi.fn() } },
}));

import { auth } from "@/lib/auth";
import { GET } from "./route";

describe("GET /api/me", () => {
  it("returns 401 without a session", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValueOnce(null);
    const res = await GET(new Request("http://test/api/me"));
    expect(res.status).toBe(401);
  });

  it("returns the user when signed in", async () => {
    const createdAt = new Date("2026-01-02T03:04:05.000Z");
    const session = {
      user: { id: "u1", name: "Alex", email: "a@b.c", createdAt },
      session: {},
    };
    vi.mocked(auth.api.getSession).mockResolvedValueOnce(session as never);
    const res = await GET(new Request("http://test/api/me"));
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({
      user: {
        id: "u1",
        name: "Alex",
        email: "a@b.c",
        createdAt: "2026-01-02T03:04:05.000Z",
      },
    });
  });
});
