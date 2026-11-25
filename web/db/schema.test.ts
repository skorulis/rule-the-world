import { getTableName } from "drizzle-orm";
import { getTableConfig } from "drizzle-orm/pg-core";
import { describe, expect, it } from "vitest";
import { hexDetails, hexVisit, hexVisitDay, playerRanking } from "./schema";
import { user } from "./auth-schema";

describe("player ranking schema", () => {
  it("stores the six ranking fields in typed, non-null columns", () => {
    expect(getTableName(playerRanking)).toBe("player_ranking");
    const columns = getTableConfig(playerRanking).columns;
    expect(columns.map((column) => [column.name, column.getSQLType(), column.notNull])).toEqual([
      ["user_id", "text", true], ["region_id", "bigint", true], ["region_type", "text", true],
      ["visit_count", "integer", true], ["owned_count", "integer", true], ["rank_number", "integer", true],
    ]);
    expect(playerRanking.regionId.mapFromDriverValue("1159320379")).toBe(1159320379);
  });

  it("keys a player's ranking by type and region and cascades player deletion", () => {
    const config = getTableConfig(playerRanking);
    expect(config.primaryKeys[0].columns.map((column) => column.name)).toEqual(["user_id", "region_type", "region_id"]);
    expect(config.foreignKeys[0].onDelete).toBe("cascade");
    expect(config.foreignKeys[0].reference().foreignTable).toBe(user);
    expect(config.uniqueConstraints).toHaveLength(0);
    expect(config.checks.map(({ name }) => name)).toEqual([
      "player_ranking_region_id_positive", "player_ranking_region_type_valid",
      "player_ranking_visit_count_nonnegative", "player_ranking_owned_count_nonnegative",
      "player_ranking_rank_number_positive",
    ]);
  });
});

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
    expect(hexDetails.regionSuburb.getSQLType()).toBe("bigint");
    expect(hexDetails.regionCountry.notNull).toBe(false);
    expect(hexDetails.regionState.notNull).toBe(false);
    expect(hexDetails.regionSuburb.notNull).toBe(false);
    expect(getTableConfig(hexDetails).checks.map(({ name }) => name)).toEqual([
      "hex_details_region_country_positive", "hex_details_region_state_positive",
      "hex_details_region_suburb_positive",
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
