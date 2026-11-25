import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("@/lib/auth", () => ({ auth: { api: { getSession: vi.fn() } } }));
vi.mock("@/lib/visits/ingest-visits", () => ({ ingestVisits: vi.fn() }));

import { auth } from "@/lib/auth";
import { ingestVisits } from "@/lib/visits/ingest-visits";
import { maxBodyBytes } from "@/lib/visits/visit-batch";
import { POST } from "./route";

const visit = { id: "123", cell: "8a2830828007fff", timestamp: "2026-11-20T10:00:00Z", score: 0.5 };
const request = (body: unknown = { visits: [visit] }) => new Request("http://test/api/hex-visits/batch", {
  method: "POST", body: JSON.stringify(body), headers: { "content-type": "application/json" },
});

beforeEach(() => {
  vi.resetAllMocks();
  vi.mocked(auth.api.getSession).mockResolvedValue({ user: { id: "u1" }, session: {} } as never);
});

describe("POST /api/hex-visits/batch", () => {
  it("requires authentication before ingestion", async () => {
    vi.mocked(auth.api.getSession).mockResolvedValueOnce(null);
    expect((await POST(request())).status).toBe(401);
    expect(ingestVisits).not.toHaveBeenCalled();
  });

  it("uses the signed-in player, not a submitted player ID", async () => {
    const userVisit = { cell: visit.cell, lastVisit: visit.timestamp, total: 1, score: 0.5, lastScore: 0.5 };
    const result = {
      acceptedIds: ["123"], visits: [userVisit],
      hexInfos: [{ cell: visit.cell, totals: { totalVisits: 4, rivalScore: 1 }, regions: null, userVisit }],
      rankings: [],
    };
    vi.mocked(ingestVisits).mockResolvedValueOnce(result);
    const response = await POST(request({ userId: "someone-else", visits: [visit] }));
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual(result);
    expect(ingestVisits).toHaveBeenCalledWith("u1", expect.objectContaining({ acceptedIds: ["123"] }));
  });

  it.each([null, {}, { visits: [visit, { ...visit, id: "bad", score: 2 }] }])("rejects the entire invalid batch %j", async (body) => {
    expect((await POST(request(body))).status).toBe(400);
    expect(ingestVisits).not.toHaveBeenCalled();
  });

  it("rejects invalid JSON", async () => {
    expect((await POST(new Request("http://test", { method: "POST", body: "{" }))).status).toBe(400);
  });

  it("returns 413 for oversized bodies", async () => {
    expect((await POST(new Request("http://test", { method: "POST", body: " ".repeat(maxBodyBytes + 1) }))).status).toBe(413);
    expect(ingestVisits).not.toHaveBeenCalled();
  });

  it("does not acknowledge before persistence completes", async () => {
    let complete!: (value: Awaited<ReturnType<typeof ingestVisits>>) => void;
    vi.mocked(ingestVisits).mockImplementationOnce(() => new Promise((resolve) => { complete = resolve; }));
    let finished = false;
    const response = POST(request()).then((result) => { finished = true; return result; });
    await vi.waitFor(() => expect(ingestVisits).toHaveBeenCalled());
    expect(finished).toBe(false);
    complete({ acceptedIds: ["123"], visits: [], hexInfos: [], rankings: [] });
    expect((await response).status).toBe(200);
  });

  it("does not expose or log database error details or acknowledge failures", async () => {
    const logger = vi.spyOn(console, "error").mockImplementation(() => {});
    try {
      vi.mocked(ingestVisits).mockRejectedValueOnce(new Error("private visit SQL parameters"));
      const response = await POST(request());
      expect(response.status).toBe(500);
      expect(await response.json()).toEqual({ error: "Unable to upload visits" });
      expect(logger).toHaveBeenCalledWith("Visit batch upload failed", undefined);
    } finally {
      logger.mockRestore();
    }
  });
});
