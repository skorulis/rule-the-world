import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("@/lib/rankings/calculate-rankings", () => ({ calculateRankings: vi.fn() }));

import { calculateRankings } from "@/lib/rankings/calculate-rankings";
import { GET } from "./route";

const summary = { regions: 1, players: 1, assignments: 1, durationMs: 1 };
const request = (authorization?: string) => new Request("http://test/api/cron/calculate_rankings", {
  headers: authorization ? { authorization } : {},
});

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(calculateRankings).mockResolvedValue(summary);
});

afterEach(() => {
  vi.unstubAllEnvs();
});

describe("GET /api/cron/calculate_rankings", () => {
  it("rejects requests without the cron secret", async () => {
    vi.stubEnv("CRON_SECRET", "s3cret");
    expect((await GET(request())).status).toBe(401);
    expect((await GET(request("Bearer wrong"))).status).toBe(401);
    expect(calculateRankings).not.toHaveBeenCalled();
  });

  it("runs with the correct cron secret", async () => {
    vi.stubEnv("CRON_SECRET", "s3cret");
    const response = await GET(request("Bearer s3cret"));
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual(summary);
  });

  it("runs without auth when no secret is configured", async () => {
    vi.stubEnv("CRON_SECRET", "");
    expect((await GET(request())).status).toBe(200);
  });

  it("sanitizes failures", async () => {
    vi.stubEnv("CRON_SECRET", "");
    const logger = vi.spyOn(console, "error").mockImplementation(() => {});
    try {
      vi.mocked(calculateRankings).mockRejectedValueOnce(new Error("private SQL"));
      const response = await GET(request());
      expect(response.status).toBe(500);
      expect(await response.json()).toEqual({ error: "Unable to calculate rankings" });
    } finally {
      logger.mockRestore();
    }
  });
});
