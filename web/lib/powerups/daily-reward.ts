import type { PowerUpRarity } from "./powerups";

export const dailyRewardRarity: PowerUpRarity = "common";

/** The UTC calendar day of `now` as `YYYY-MM-DD`. */
export function utcDay(now: Date): string {
  return now.toISOString().slice(0, 10);
}

/** The next 00:00 UTC strictly after `now`. */
export function nextDailyReset(now: Date): Date {
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1));
}

/** When the daily reward can next be claimed, given the UTC day it was last claimed. */
export function dailyRewardAvailableAt(lastDay: string | null | undefined, now: Date): Date {
  return lastDay === utcDay(now) ? nextDailyReset(now) : now;
}
