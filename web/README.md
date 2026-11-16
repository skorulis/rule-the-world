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

## Deployment

Deployed to Vercel with the project's Root Directory set to `web`. No `vercel.json` needed.

## Notes

If `next dev` (Turbopack) misbehaves, you can fall back to `next dev --webpack`.
