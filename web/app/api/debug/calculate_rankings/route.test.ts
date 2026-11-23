import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("@/lib/rankings/calculate-rankings", () => ({ calculateRankings: vi.fn() }));

import { calculateRankings } from "@/lib/rankings/calculate-rankings";
import { GET, POST } from "./route";

const summary = { regions: 2, players: 3, assignments: 4, durationMs: 5 };

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(calculateRankings).mockResolvedValue(summary);
});

describe("/api/debug/calculate_rankings", () => {
  it("recalculates rankings and returns the summary", async () => {
    const response = await GET();
    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("private, no-store");
    expect(await response.json()).toEqual(summary);
    expect(POST).toBe(GET);
  });

  it("sanitizes failures", async () => {
    const logger = vi.spyOn(console, "error").mockImplementation(() => {});
    try {
      vi.mocked(calculateRankings).mockRejectedValueOnce(new Error("private SQL"));
      const response = await GET();
      expect(response.status).toBe(500);
      expect(await response.json()).toEqual({ error: "Unable to calculate rankings" });
    } finally {
      logger.mockRestore();
    }
  });
});
