<!-- BEGIN:nextjs-agent-rules -->
# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` before writing any code. Heed deprecation notices.
<!-- END:nextjs-agent-rules -->

## Region geometry and maintenance

- Canonical suburb geometry is `../data/regions/suburbs-medium.geojson`; `data/regions/suburbs-medium.geojson` is a symlink. iOS bundles a regular-file copy.
- Regenerate from the repository root with a Python environment containing `pip install -r ios/Scripts/requirements-regions.txt`, then `python ios/Scripts/prepare-suburb-boundaries.py`. Generation validates source deviation and synchronizes the iOS geometry and metadata. `python ios/Scripts/prepare-suburb-boundaries.py --validate-only` checks local assets without downloading.
- `npm run regions:repair` is a read-only classification repair dry run using `DATABASE_URL` (or `.env.local`). `npm run regions:repair -- --apply` updates only changed region fields in guarded transactional batches. Never run either against a database without explicit user approval; review the dry-run report before approving apply.
- Changing geometry does not refresh cached `hex_details` rows automatically. Deploy the matching API data/classifier before a separately authorized repair.
- Focused static verification: `npx tsc --noEmit --incremental false` and ESLint on changed TypeScript files. Relevant test files are `lib/regions/country-regions.test.ts`, `region-hierarchy.test.ts`, `hex-details.test.ts`, and `repair-hex-details.test.ts`; do not execute test suites unless explicitly authorized.
