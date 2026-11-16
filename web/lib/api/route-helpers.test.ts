import { describe, expect, it, vi } from "vitest";

vi.mock("@/lib/auth", () => ({
  auth: { api: { getSession: vi.fn() } },
}));

import { auth } from "@/lib/auth";
import {
  jsonError,
  parsePositiveId,
  requireSession,
} from "./route-helpers";

describe("jsonError", () => {
  it("returns the given status and error body", async () => {
    const res = jsonError("Nope", 403);
    expect(res.status).toBe(403);
    expect(await res.json()).toEqual({ error: "Nope" });
  });
});

describe("parsePositiveId", () => {
  it.each([
    [5, 5],
    ["5", 5],
    ["0", null],
    [0, null],
    ["abc", null],
    [1.5, null],
    [-3, null],
    ["", null],
    [undefined, null],
  ])("parsePositiveId(%j) -> %j", (input, expected) => {
    expect(parsePositiveId(input)).toBe(expected);
  });
});

describe("requireSession", () => {
  it("returns a 401 response when signed out", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValueOnce(null);
    const result = await requireSession(new Request("http://test"));
    expect(result).toBeInstanceOf(Response);
    expect((result as Response).status).toBe(401);
  });

  it("returns the session when signed in", async () => {
    const session = { user: { id: "u1" }, session: {} };
    vi.mocked(auth.api.getSession).mockResolvedValueOnce(session as never);
    expect(await requireSession(new Request("http://test"))).toBe(session);
  });
});
