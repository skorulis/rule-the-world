import { describe, expect, it } from "vitest";
import { isVisitCell, maxBatchSize, maxBodyBytes, parseVisitBatch, readVisitBody } from "./visit-batch";

const cell = "8a2830828007fff";
const cellId = BigInt(`0x${cell}`);
const visit = { id: "1", cell, timestamp: "2026-11-20T10:00:00Z", score: 0.5 };

describe("visit batches", () => {
  it("keeps full cell precision and groups by UTC day with maximum scores", () => {
    const result = parseVisitBatch({ visits: [
      visit,
      { ...visit, id: "2", score: 1, timestamp: "2026-11-20T11:00:00Z" },
      { ...visit, id: "3", score: 0, timestamp: "2026-11-20T23:30:00-02:00" },
    ] });
    expect(result.acceptedIds).toEqual(["1", "2", "3"]);
    expect(result.counts).toEqual([
      { id: "1", cell: cellId, count: 1 }, { id: "2", cell: cellId, count: 1 }, { id: "3", cell: cellId, count: 1 },
    ]);
    expect(result.days).toEqual([{ cell: cellId, day: "2026-11-20", score: 1 }, { cell: cellId, day: "2026-11-21", score: 0 }]);
    expect(result.cells).toEqual([{ cell: cellId, lastVisit: new Date("2026-11-21T01:30:00Z") }]);
  });

  it("preserves grouped visit counts independently of score", () => {
    const result = parseVisitBatch({ visits: [{ ...visit, count: 7, score: 0 }] });
    expect(result.counts).toEqual([{ id: "1", cell: cellId, count: 7 }]);
    expect(result.days[0].score).toBe(0);
  });

  it("sorts cells and days independently of upload order", () => {
    const other = "8a2830828017fff";
    const result = parseVisitBatch({ visits: [
      { ...visit, cell: other },
      { ...visit, id: "2", timestamp: "2026-11-19T10:00:00Z" },
    ] });
    expect(result.cells.map((row) => row.cell)).toEqual([cellId, BigInt(`0x${other}`)]);
  });

  it.each([null, [], {}, { visits: [] }, { visits: [null] }, { visits: Array(maxBatchSize + 1).fill(visit) }])(
    "rejects malformed batch %j", (body) => expect(() => parseVisitBatch(body)).toThrow(),
  );

  it.each([
    { id: "" }, { id: " " }, { id: "x".repeat(129) }, { id: 1 },
    { cell: Number(BigInt(`0x${cell}`)) }, { cell: cell.toUpperCase() }, { cell: "89283082803ffff" },
    { count: 0 }, { count: -1 }, { count: 1.5 }, { count: "2" }, { count: 2_147_483_648 },
    { score: -0.1 }, { score: 1.1 }, { score: NaN }, { score: Infinity }, { score: "1" },
    { timestamp: "2026-11-20T10:00:00" }, { timestamp: "2026-02-30T00:00:00Z" },
    { timestamp: "2026-11-20T24:00:00Z" }, { timestamp: "2026-11-20T00:00:00+24:00" },
  ])("rejects invalid fields %j", (fields) => {
    expect(() => parseVisitBatch({ visits: [{ ...visit, ...fields }] })).toThrow();
  });

  it("rejects duplicate acknowledgement IDs", () => {
    expect(() => parseVisitBatch({ visits: [visit, visit] })).toThrow(/duplicate/);
  });

  it("validates H3 base cells, active and unused digits, and pentagon deleted subsequences", () => {
    expect(isVisitCell(cell)).toBe(true);
    expect(isVisitCell("8afffffffffffff")).toBe(false);
    const base = (BigInt(1) << BigInt(59)) | (BigInt(10) << BigInt(52)) | (BigInt(4) << BigInt(45)) | BigInt(32767);
    expect(isVisitCell(base.toString(16))).toBe(true);
    expect(isVisitCell((base | (BigInt(1) << BigInt(42))).toString(16))).toBe(false);
    expect(isVisitCell((base | (BigInt(7) << BigInt(42))).toString(16))).toBe(false);
    expect(isVisitCell((base ^ BigInt(1)).toString(16))).toBe(false);
  });

  it("accepts the maximum batch size", () => {
    expect(parseVisitBatch({ visits: Array.from({ length: maxBatchSize }, (_, id) => ({ ...visit, id: String(id) })) }).acceptedIds).toHaveLength(maxBatchSize);
  });
});

describe("bounded JSON reader", () => {
  it("reads JSON", async () => {
    expect(await readVisitBody(new Request("http://test", { method: "POST", body: JSON.stringify({ visits: [visit] }) }))).toEqual({ visits: [visit] });
  });

  it.each(["", "{", "null garbage"])("rejects invalid JSON %j", async (body) => {
    await expect(readVisitBody(new Request("http://test", { method: "POST", body }))).rejects.toMatchObject({ status: 400 });
  });

  it("limits bytes even without a Content-Length header", async () => {
    const request = new Request("http://test", { method: "POST", body: "é".repeat(maxBodyBytes) });
    expect(request.headers.has("content-length")).toBe(false);
    await expect(readVisitBody(request)).rejects.toMatchObject({ status: 413 });
  });

  it("rejects oversized declared bodies", async () => {
    await expect(readVisitBody(new Request("http://test", {
      method: "POST", body: "{}", headers: { "content-length": String(maxBodyBytes + 1) },
    }))).rejects.toMatchObject({ status: 413 });
  });
});
