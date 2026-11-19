# Rule The World

An iOS app backed by a Next.js API server. This repository is a monorepo
containing both halves of the product:

- [`ios/`](ios/) — the native iOS app (`RuleTheWorld`), built with Swift/Xcode.
  See [ios/README.md](ios/README.md) for build/verification commands and
  [ios/Architecture.md](ios/Architecture.md) for architectural decisions.
- [`web/`](web/) — the API server for the iOS app: Next.js (App Router),
  better-auth, Drizzle/Postgres, deployed to Vercel. See
  [web/README.md](web/README.md) for local setup, auth, database, and
  deployment details.
