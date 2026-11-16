import { config } from "dotenv";

/** Loads env for CLI scripts (migrate, generate): `.env` then `.env.local` (local dev overrides). */
export function loadScriptEnv(): void {
  config({ path: ".env" });
  config({ path: ".env.local", override: true });
}
