import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("@/lib/auth", () => ({ auth: { api: { getSession: vi.fn() } } }));
vi.mock("@/lib/powerups/consume-powerup", async (importOriginal) => ({
  ...(await importOriginal<typeof import("@/lib/powerups/consume-powerup")>()),
  consumePowerUp: vi.fn(),
}));

import { auth } from "@/lib/auth";
import { consumePowerUp, ConsumePowerUpError } from "@/lib/powerups/consume-powerup";
import { powerUpDefinitions } from "@/lib/powerups/powerups";
import { POST } from "./route";

const user = { id: "u1", name: "Alex", email: "a@b.c" };
const definition = powerUpDefinitions[0];
const request = (body: unknown = { powerup: definition.id, location: { latitude: 37.7, longitude: -122.4 } }) =>
  new Request("http://test/api/powerup/consume", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

const visit = {
  totals: { totalVisits: 3, rivalScore: 0 },
  userVisit: {
    cell: "8a2830828767fff",
    total: 2,
    lastVisit: "2026-11-20T10:00:00.000Z",
    score: 5,
    lastScore: 0.5,
  },
};

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(auth.api.getSession).mockResolvedValue({ user, session: {} } as never);
  vi.mocked(consumePowerUp).mockResolvedValue({ powerups: { "2": 1 }, visits: [visit] });
});

describe("POST /api/powerup/consume", () => {
  it("requires authentication", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValueOnce(null);
    expect((await POST(request())).status).toBe(401);
    expect(consumePowerUp).not.toHaveBeenCalled();
  });

  it("rejects malformed JSON", async () => {
    const response = await POST(new Request("http://test/api/powerup/consume", {
      method: "POST",
      body: "nope",
    }));
    expect(response.status).toBe(400);
  });

  it("rejects unknown or missing power-up ids", async () => {
    for (const powerup of [undefined, 0, -1, 99999, "abc"]) {
      const response = await POST(request({ powerup, location: { latitude: 0, longitude: 0 } }));
      expect(response.status).toBe(400);
      expect(await response.json()).toEqual({ error: "Unknown power-up" });
    }
    expect(consumePowerUp).not.toHaveBeenCalled();
  });

  it.each([
    { location: undefined },
    { location: {} },
    { location: { latitude: "x", longitude: 0 } },
    { location: { latitude: 91, longitude: 0 } },
    { location: { latitude: 0, longitude: -181 } },
    { location: { latitude: NaN, longitude: 0 } },
  ])("rejects invalid location %#", async (body) => {
    const response = await POST(request({ powerup: definition.id, ...body }));
    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: "Invalid location" });
    expect(consumePowerUp).not.toHaveBeenCalled();
  });

  it("applies the power-up and returns inventory plus changed hexes", async () => {
    const response = await POST(request());
    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("private, no-store");
    expect(await response.json()).toEqual({ powerups: { "2": 1 }, visits: [visit] });
    const [userId, def, cell] = vi.mocked(consumePowerUp).mock.calls[0];
    expect(userId).toBe("u1");
    expect(def).toEqual(definition);
    expect(typeof cell).toBe("bigint");
  });

  it("maps domain errors to responses without consuming", async () => {
    vi.mocked(consumePowerUp).mockRejectedValueOnce(new ConsumePowerUpError("Power-up not in inventory"));
    expect((await POST(request())).status).toBe(400);
    vi.mocked(consumePowerUp).mockRejectedValueOnce(new ConsumePowerUpError("No visited hex in range", 404));
    expect((await POST(request())).status).toBe(404);
  });

  it("sanitizes database failures", async () => {
    const logger = vi.spyOn(console, "error").mockImplementation(() => {});
    try {
      vi.mocked(consumePowerUp).mockRejectedValueOnce(new Error("private SQL"));
      const response = await POST(request());
      expect(response.status).toBe(500);
      expect(await response.json()).toEqual({ error: "Unable to consume power-up" });
    } finally {
      logger.mockRestore();
    }
  });
});
