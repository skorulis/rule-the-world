// App-specific tables go here. Auth tables live in auth-schema.ts.
import { sql } from "drizzle-orm";
import { check, date, foreignKey, integer, numeric, pgTable, primaryKey, text, timestamp } from "drizzle-orm/pg-core";
import { user } from "./auth-schema";

export const hexVisit = pgTable("hex_visit", {
  userId: text("user_id").notNull().references(() => user.id, { onDelete: "cascade" }),
  cell: text("cell").notNull(),
  lastVisit: timestamp("last_visit", { withTimezone: true }).notNull(),
  score: numeric("score").notNull().default("0"),
  total: integer("total").notNull().default(0),
  lastScore: numeric("last_score").notNull().default("0"),
}, (table) => [
  primaryKey({ columns: [table.userId, table.cell] }),
  check("hex_visit_total_nonnegative", sql`${table.total} >= 0`),
  check("hex_visit_score_nonnegative", sql`${table.score} >= 0 AND ${table.score} < 'Infinity'::numeric`),
  check("hex_visit_last_score_range", sql`${table.lastScore} BETWEEN 0 AND 1`),
]);

export const noRegion = "none";

export const hexRegion = pgTable("hex_region", {
  cell: text("cell").primaryKey(),
  region: text("region").notNull(),
}, (table) => [
  check("hex_region_region_nonempty", sql`${table.region} <> ''`),
]);

export const hexVisitUpload = pgTable("hex_visit_upload", {
  userId: text("user_id").notNull().references(() => user.id, { onDelete: "cascade" }),
  id: text("id").notNull(),
  cell: text("cell").notNull(),
  count: integer("count").notNull(),
}, (table) => [
  primaryKey({ columns: [table.userId, table.id] }),
  check("hex_visit_upload_count_positive", sql`${table.count} > 0`),
]);

export const hexVisitDay = pgTable("hex_visit_day", {
  userId: text("user_id").notNull(),
  cell: text("cell").notNull(),
  day: date("day").notNull(),
  score: numeric("score").notNull(),
}, (table) => [
  primaryKey({ columns: [table.userId, table.cell, table.day] }),
  foreignKey({ columns: [table.userId, table.cell], foreignColumns: [hexVisit.userId, hexVisit.cell] }).onDelete("cascade"),
  check("hex_visit_day_score_range", sql`${table.score} BETWEEN 0 AND 1`),
]);
