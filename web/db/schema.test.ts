import { getTableName } from "drizzle-orm";
import { getTableConfig } from "drizzle-orm/pg-core";
import { describe, expect, it } from "vitest";
import { hexDetails, hexVisit, hexVisitDay } from "./schema";

describe("visit score schema", () => {
  it("keys aggregates by user/cell and daily summaries by user/cell/day", () => {
    expect(getTableName(hexVisit)).toBe("hex_visit");
    expect(getTableName(hexVisitDay)).toBe("hex_visit_day");
    expect(getTableName(hexDetails)).toBe("hex_details");
    expect(getTableConfig(hexDetails).primaryKeys[0].columns.map((column) => column.name)).toEqual(["cell"]);
    expect(hexDetails.cell.getSQLType()).toBe("bigint");
    expect(hexDetails.cell.notNull).toBe(true);
    expect(hexDetails.regionCountry.getSQLType()).toBe("bigint");
    expect(hexDetails.regionState.getSQLType()).toBe("bigint");
    expect(hexDetails.regionCountry.notNull).toBe(false);
    expect(hexDetails.regionState.notNull).toBe(false);
    expect(getTableConfig(hexDetails).checks.map(({ name }) => name)).toEqual([
      "hex_details_region_country_positive", "hex_details_region_state_positive",
    ]);
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
