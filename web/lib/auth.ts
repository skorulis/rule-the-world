import { betterAuth } from "better-auth";
import { drizzleAdapter } from "better-auth/adapters/drizzle";
import { bearer } from "better-auth/plugins";
import { db } from "@/lib/db";

export const auth = betterAuth({
  secret: process.env.BETTER_AUTH_SECRET,
  baseURL: process.env.BETTER_AUTH_URL,
  database: drizzleAdapter(db, { provider: "pg" }),
  session: {
    expiresIn: 60 * 60 * 24 * 30, // 30 days
    updateAge: 60 * 60 * 24, // extend expiry when used at least once per day
  },
  emailAndPassword: {
    enabled: true,
    requireEmailVerification: false,
  },
  // Google / Apple sign-in will be added here via `socialProviders` later.
  // `bearer()` lets the iOS app authenticate with `Authorization: Bearer <token>`
  // (token comes back in the `set-auth-token` response header on sign-in/sign-up).
  plugins: [bearer()],
});

export type Session = typeof auth.$Infer.Session;
