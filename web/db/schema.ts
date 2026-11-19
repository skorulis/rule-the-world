// App-specific tables go here. Auth tables live in auth-schema.ts.
import { sql } from "drizzle-orm";
import { check, date, foreignKey, numeric, pgTable, primaryKey, text, timestamp } from "drizzle-orm/pg-core";
import { user } from "./auth-schema";

export const hexVisit = pgTable("hex_visit", {
  userId: text("user_id").notNull().references(() => user.id, { onDelete: "cascade" }),
  cell: text("cell").notNull(),
  lastVisit: timestamp("last_visit", { withTimezone: true }).notNull(),
  score: numeric("score").notNull().default("0"),
  lastScore: numeric("last_score").notNull().default("0"),
}, (table) => [
  primaryKey({ columns: [table.userId, table.cell] }),
  check("hex_visit_score_nonnegative", sql`${table.score} >= 0 AND ${table.score} < 'Infinity'::numeric`),
  check("hex_visit_last_score_range", sql`${table.lastScore} BETWEEN 0 AND 1`),
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
