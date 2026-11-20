import { getTableName } from "drizzle-orm";
import { getTableConfig } from "drizzle-orm/pg-core";
import { describe, expect, it } from "vitest";
import { hexRegion, hexVisit, hexVisitDay } from "./schema";

describe("visit score schema", () => {
  it("keys aggregates by user/cell and daily summaries by user/cell/day", () => {
    expect(getTableName(hexVisit)).toBe("hex_visit");
    expect(getTableName(hexVisitDay)).toBe("hex_visit_day");
    expect(getTableName(hexRegion)).toBe("hex_region");
    expect(getTableConfig(hexRegion).primaryKeys[0].columns.map((column) => column.name)).toEqual(["cell", "region_type"]);
    expect(getTableConfig(hexVisit).primaryKeys[0].columns.map((column) => column.name)).toEqual(["user_id", "cell"]);
    expect(getTableConfig(hexVisitDay).primaryKeys[0].columns.map((column) => column.name)).toEqual(["user_id", "cell", "day"]);
  });

  it("cascades user deletion through aggregates to daily scores", () => {
    expect(getTableConfig(hexVisit).foreignKeys[0].onDelete).toBe("cascade");
    expect(getTableConfig(hexVisitDay).foreignKeys[0].onDelete).toBe("cascade");
    expect(getTableConfig(hexVisitDay).foreignKeys[0].reference().foreignTable).toBe(hexVisit);
  });

  it("uses exact scores, bounded daily scores, and timezone-aware visit dates", () => {
    expect(hexVisit.score.getSQLType()).toBe("numeric");
    expect(hexVisit.lastVisit.getSQLType()).toBe("timestamp with time zone");
    expect(hexVisit.total.getSQLType()).toBe("integer");
    expect(getTableConfig(hexVisit).checks).toHaveLength(3);
    expect(getTableConfig(hexVisitDay).checks).toHaveLength(1);
  });
});
