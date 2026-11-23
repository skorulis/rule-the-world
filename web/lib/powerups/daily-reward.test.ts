import { describe, expect, it } from "vitest";
import { dailyRewardAvailableAt, dailyRewardRarity, nextDailyReset, utcDay } from "./daily-reward";

describe("daily reward", () => {
  it("grants common power-ups", () => {
    expect(dailyRewardRarity).toBe("common");
  });

  it("utcDay uses the UTC calendar day", () => {
    expect(utcDay(new Date("2026-11-23T00:00:00.000Z"))).toBe("2026-11-23");
    expect(utcDay(new Date("2026-11-23T23:59:59.999Z"))).toBe("2026-11-23");
    expect(utcDay(new Date("2026-11-24T09:00:00+10:00"))).toBe("2026-11-23");
  });

  it("nextDailyReset is the following UTC midnight", () => {
    expect(nextDailyReset(new Date("2026-11-23T15:30:00.000Z")).toISOString()).toBe("2026-11-24T00:00:00.000Z");
    expect(nextDailyReset(new Date("2026-11-23T00:00:00.000Z")).toISOString()).toBe("2026-11-24T00:00:00.000Z");
    expect(nextDailyReset(new Date("2026-11-23T23:59:59.999Z")).toISOString()).toBe("2026-11-24T00:00:00.000Z");
    expect(nextDailyReset(new Date("2026-12-31T12:00:00.000Z")).toISOString()).toBe("2027-01-01T00:00:00.000Z");
    expect(nextDailyReset(new Date("2028-02-28T12:00:00.000Z")).toISOString()).toBe("2028-02-29T00:00:00.000Z");
  });

  it("is available now unless already claimed today", () => {
    const now = new Date("2026-11-23T15:30:00.000Z");
    expect(dailyRewardAvailableAt(null, now)).toBe(now);
    expect(dailyRewardAvailableAt(undefined, now)).toBe(now);
    expect(dailyRewardAvailableAt("2026-11-22", now)).toBe(now);
    expect(dailyRewardAvailableAt("2026-11-23", now).toISOString()).toBe("2026-11-24T00:00:00.000Z");
  });

  it("becomes available again exactly at UTC midnight", () => {
    expect(dailyRewardAvailableAt("2026-11-23", new Date("2026-11-23T23:59:59.999Z")).toISOString())
      .toBe("2026-11-24T00:00:00.000Z");
    const midnight = new Date("2026-11-24T00:00:00.000Z");
    expect(dailyRewardAvailableAt("2026-11-23", midnight)).toBe(midnight);
  });
});
