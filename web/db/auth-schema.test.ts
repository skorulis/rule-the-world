import { getTableName } from "drizzle-orm";
import { getTableConfig } from "drizzle-orm/pg-core";
import { describe, expect, it } from "vitest";
import { account, session, user, verification } from "./auth-schema";

describe("auth schema table names", () => {
  it("does not store rankings on the user", () => {
    expect(getTableConfig(user).columns.map((column) => column.name)).not.toContain("rankings");
  });

  it("uses the better-auth table names", () => {
    expect(getTableName(user)).toBe("user");
    expect(getTableName(session)).toBe("session");
    expect(getTableName(account)).toBe("account");
    expect(getTableName(verification)).toBe("verification");
  });
});
