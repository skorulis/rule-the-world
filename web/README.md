# rule-the-world-web

API server for the Rule The World iOS app. Next.js App Router, deploy target Vercel.

## Running

```bash
npm install
npm run dev
curl http://localhost:3000/health
```

## Verification

```bash
npm run lint
npm test
npx tsc --noEmit
```

## Notes

If `next dev` (Turbopack) misbehaves, you can fall back to `next dev --webpack`.

## Database setup (local)

```bash
docker compose up -d        # Postgres 16 on localhost:5433
cp .env.example .env.local  # then set BETTER_AUTH_SECRET (openssl rand -base64 32)
npm run db:migrate
docker compose ps           # check the container is healthy
```

## Auth

Auth is [better-auth](https://www.better-auth.com) with email/password only — no
email verification for now. All auth routes live under `/api/auth/*`
(`app/api/auth/[...all]/route.ts`). The `bearer()` plugin is enabled, so the iOS
app can authenticate with `Authorization: Bearer <token>`.

```bash
# Sign up — -i shows the set-auth-token response header
curl -i -X POST http://localhost:3000/api/auth/sign-up/email \
  -H 'Content-Type: application/json' \
  -d '{"name":"Alex","email":"a@b.c","password":"password123"}'

# Sign in
curl -i -X POST http://localhost:3000/api/auth/sign-in/email \
  -H 'Content-Type: application/json' \
  -d '{"email":"a@b.c","password":"password123"}'

TOKEN=... # token from the set-auth-token header
curl http://localhost:3000/api/auth/get-session -H "Authorization: Bearer $TOKEN"
curl http://localhost:3000/api/me            -H "Authorization: Bearer $TOKEN"
```

`GET /api/me` returns `401 {"error":"Unauthorized"}` without a valid token.

## Schema changes

1. Edit `db/*.ts`
2. `npm run db:generate`
3. Commit the generated files under `db/migrations/`
4. `npm run db:migrate`

## Deployment

Deployed to Vercel with the project's Root Directory set to `web`. No `vercel.json` needed.

- Add a Neon database via the Vercel Marketplace integration — it injects `DATABASE_URL` automatically (use the pooled connection string).
- Set `BETTER_AUTH_SECRET` and `BETTER_AUTH_URL` in the Vercel project env vars.
- Run migrations from your machine with `DATABASE_URL` pointed at Neon:

  ```bash
  DATABASE_URL=postgresql://...neon... npm run db:migrate
  ```
