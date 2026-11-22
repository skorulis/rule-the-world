import { PgDialect } from "drizzle-orm/pg-core";
import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("@/lib/db", () => ({ db: { select: vi.fn(), execute: vi.fn() } }));

import { hexDetails, hexVisit } from "@/db/schema";
import { db } from "@/lib/db";
import { GET } from "./route";

beforeEach(() => vi.resetAllMocks());

describe("GET /api/stats", () => {
  it("counts detail cells and returns country/state memberships without changing the response shape", async () => {
    const from = vi.fn().mockResolvedValueOnce([{ value: 5 }]).mockResolvedValueOnce([{ value: 3 }]);
    vi.mocked(db.select).mockReturnValue({ from } as never);
    vi.mocked(db.execute).mockResolvedValueOnce([
      { region: "42", kind: 1, hexes: "2" },
      { region: "7", kind: 2, hexes: "1" },
    ] as never);

    expect(await (await GET()).json()).toEqual({
      hexVisits: 5,
      hexRegions: 3,
      regions: [
        { region: "42", kind: 1, hexes: 2 },
        { region: "7", kind: 2, hexes: 1 },
      ],
    });
    expect(from.mock.calls).toEqual([[hexVisit], [hexDetails]]);
    const statement = vi.mocked(db.execute).mock.calls[0][0];
    if (typeof statement === "string") throw new Error("Expected parameterized SQL");
    const query = new PgDialect().sqlToQuery(statement.getSQL());
    expect(query.sql).toContain('from "hex_details"');
    expect(query.sql).toContain('cross join lateral (values');
    expect(query.sql).toContain('("hex_details"."region_country", 1)');
    expect(query.sql).toContain('("hex_details"."region_state", 2)');
    expect(query.sql).toContain('("hex_details"."region_suburb", 3)');
    expect(query.sql).toContain('where membership.region is not null');
    expect(query.sql).toContain('group by membership.region, membership.kind');
    expect(query.sql).toContain('order by count(*) desc');
  });

  it("returns empty regions when no cells have region matches", async () => {
    const from = vi.fn().mockResolvedValueOnce([{ value: 2 }]).mockResolvedValueOnce([{ value: 2 }]);
    vi.mocked(db.select).mockReturnValue({ from } as never);
    vi.mocked(db.execute).mockResolvedValueOnce([] as never);
    expect(await (await GET()).json()).toEqual({ hexVisits: 2, hexRegions: 2, regions: [] });
  });
});
