import { PgDialect } from "drizzle-orm/pg-core";
import { describe, expect, it, vi } from "vitest";
import { classificationGuard, repairHexDetails, type ClassificationStore } from "./repair-hex-details";

function details(cell: number, suburb: number | null = null) {
  return {
    cell: BigInt(cell), regionCountry: BigInt(1), regionState: BigInt(2),
    regionSuburb: suburb === null ? null : BigInt(suburb),
  };
}

function harness(initial = [details(1), details(2, 3), details(3, 4)]) {
  const rows = initial.map((row) => ({ ...row }));
  const store: ClassificationStore = {
    lastCell: vi.fn(async () => rows.at(-1)?.cell),
    readBatch: vi.fn(async (after, through, limit) => rows
      .filter((row) => (after === undefined || row.cell > after) && row.cell <= through)
      .slice(0, limit).map((row) => ({ ...row }))),
    applyBatch: vi.fn(async (changes) => {
      for (const { before } of changes) {
        const row = rows.find((row) => row.cell === before.cell);
        if (!row || row.regionCountry !== before.regionCountry || row.regionState !== before.regionState
          || row.regionSuburb !== before.regionSuburb) throw new Error("Concurrent classification change");
      }
      for (const { before, after } of changes) Object.assign(rows.find((row) => row.cell === before.cell)!, after);
    }),
  };
  const classify = vi.fn((cell: bigint) => details(Number(cell), Number(cell) === 3 ? null : 3));
  return { rows, store, classify };
}

describe("repairHexDetails", () => {
  it("guards writes against all original classification fields, including nulls", () => {
    const query = new PgDialect().sqlToQuery(classificationGuard(details(1)));
    expect(query.sql).toContain('"hex_details"."cell" = $1');
    for (const column of ["region_country", "region_state", "region_suburb"]) {
      expect(query.sql).toContain(`"hex_details"."${column}" is not distinct from`);
    }
    expect(query.params).toEqual([BigInt(1), BigInt(1), BigInt(2), null]);
  });

  it("defaults to read-only dry-run and reports field transitions with bounded examples", async () => {
    const { store, classify, rows } = harness();
    const summary = await repairHexDetails(store, classify, { batchSize: 2, exampleLimit: 1 });
    expect(summary).toMatchObject({
      mode: "dry-run", scanned: 3, changed: 2, updated: 0,
      nullToAssigned: 1, assignedToNull: 1, reassigned: 0,
    });
    expect(summary.examples).toHaveLength(1);
    expect(store.applyBatch).not.toHaveBeenCalled();
    expect(rows[0].regionSuburb).toBeNull();
    expect(store.readBatch).toHaveBeenNthCalledWith(2, BigInt(2), BigInt(3), 2);
  });

  it("updates only changed rows in bounded batches and is idempotent", async () => {
    const { store, classify } = harness();
    expect(await repairHexDetails(store, classify, { apply: true, batchSize: 1 }))
      .toMatchObject({ changed: 2, updated: 2 });
    expect(store.applyBatch).toHaveBeenCalledTimes(2);
    expect(vi.mocked(store.applyBatch).mock.calls.every(([changes]) => changes.length === 1)).toBe(true);
    vi.mocked(store.applyBatch).mockClear();
    expect(await repairHexDetails(store, classify, { apply: true })).toMatchObject({ changed: 0, updated: 0 });
    expect(store.applyBatch).not.toHaveBeenCalled();
  });

  it("stops on a concurrent edit instead of overwriting it or continuing", async () => {
    const { store, classify, rows } = harness();
    classify.mockImplementation((cell) => {
      if (cell === BigInt(1)) rows[0].regionSuburb = BigInt(99);
      return details(Number(cell), 3);
    });
    await expect(repairHexDetails(store, classify, { apply: true, batchSize: 1 }))
      .rejects.toThrow("Concurrent classification change");
    expect(rows[0].regionSuburb).toBe(BigInt(99));
    expect(store.readBatch).toHaveBeenCalledTimes(1);
  });

  it("bounds the scan to its initial high-water mark", async () => {
    const { store, classify, rows } = harness([details(1)]);
    classify.mockImplementation((cell) => {
      rows.push(details(2));
      return details(Number(cell), 3);
    });
    expect(await repairHexDetails(store, classify, { batchSize: 1 })).toMatchObject({ scanned: 1 });
  });

  it("handles an empty table without reading batches or writing", async () => {
    const { store, classify } = harness([]);
    expect(await repairHexDetails(store, classify)).toMatchObject({ scanned: 0, changed: 0 });
    expect(store.readBatch).not.toHaveBeenCalled();
    expect(store.applyBatch).not.toHaveBeenCalled();
  });

  it("counts reassignment without changing cell identity", async () => {
    const { store } = harness([details(1, 7)]);
    expect(await repairHexDetails(store, (cell) => details(Number(cell), 8)))
      .toMatchObject({ changed: 1, reassigned: 1, nullToAssigned: 0, assignedToNull: 0 });
    await expect(repairHexDetails(store, () => details(99))).rejects.toThrow("Classifier changed cell identity");
  });

  it.each([0, -1, 1001, 1.5, NaN])("rejects invalid batch size %s before reading", async (batchSize) => {
    const { store, classify } = harness();
    await expect(repairHexDetails(store, classify, { batchSize })).rejects.toThrow("Invalid repair batch size");
    expect(store.lastCell).not.toHaveBeenCalled();
  });
});
