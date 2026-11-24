# Region boundary data ingestion

How canonical `data/regions/*-{medium,coarse}.pbf` datasets are produced and how
to add a new state or country. Everything here is generated — never hand-edit
the `.pbf`, `*-source.json`, or `region-names.json` outputs.

## Pipeline

```
source (FeatureServer / .osm.pbf)
  -> normalize to GeoJSON {id, name, kind, parent}
  -> merge all sources into one FeatureCollection
  -> mapshaper Douglas-Peucker simplify (keep-shapes, shared topology)
  -> repair invalid simplified rings (shapely make_valid, rounded to 1e-6)
  -> geobuf encode (region_pipeline.write_level)
  -> publish_dataset: atomic write to data/regions, sync iOS bundle + web symlink
```

Scripts (run from repo root, env per `ios/Scripts/requirements-regions.txt`):

- `prepare-country-boundaries.py` — countries from Natural Earth.
- `prepare-state-boundaries.py` — states from Natural Earth (Australia only today).
- `prepare-suburb-boundaries.py` — suburbs/localities, currently two sources merged into one dataset.
- `osm_suburbs.py` — OpenStreetMap extraction helper used by the suburb script.
- All scripts accept `--validate-only` to re-check committed artifacts.

## Sources

| Level | Source | Licence |
| --- | --- | --- |
| countries, states | Natural Earth 10m cultural (pinned git revision) | Public domain |
| NSW suburbs | NSW Administrative Boundaries FeatureServer (`portal.spatial.nsw.gov.au`) | CC BY |
| Other AU suburbs | OpenStreetMap `boundary=administrative`, `admin_level=9` (+`10`), via pinned Geofabrik `.osm.pbf` extract | ODbL 1.0 — requires "© OpenStreetMap contributors" attribution |

OpenStreetMap was chosen as the central source for suburb-level regions: the
same tagging schema (`admin_level` per country) works worldwide, and in
Australia the data derives from the authoritative cadastral imports.

## Region ids

Ids are strings of a numeric identity that must never collide across levels or
change once shipped — `hex_details`/`visits` rows store them. Ranges:

- `1159xxxxxx` — Natural Earth `ne_id` (countries and states).
- `9_000_000_000_000` + NSW `cadid` — NSW suburbs (`ID_BASE`).
- `9_200_000_000_000` + OSM relation id — OSM suburbs (`osm_suburbs.OSM_ID_BASE`).

**Never re-source a live region.** Changing e.g. NSW suburbs to OSM ids would
remap every id and orphan stored visits. New states/countries get a fresh id
scheme or a source-stable key. OSM relation ids are stable in practice but a
deleted-and-recreated relation will get a new id — treat id changes as
breaking changes needing a data repair (`npm run regions:repair`).

## Suburb dataset details (`prepare-suburb-boundaries.py`)

- NSW features keep their FeatureServer download path, `ID_BASE + cadid` ids,
  and regression points.
- `osm_suburbs.collect_suburbs()` assembles multipolygons from OSM relations
  using libosmium's `AreaManager` (requires the `osmium` Python package — add
  to `requirements-regions.txt` if missing).
- Each OSM suburb's `parent` is the `admin_level=4` relation covering its
  representative point, mapped to the Natural Earth state id from
  `states-medium.pbf`. Suburbs in NSW, external territories absent from
  `states-medium.pbf` (Christmas Island, Cocos, Norfolk, etc.), and anywhere
  outside a state border are skipped.
- Quality gate (`geometry_quality`): per-feature boundary Hausdorff distance
  in local equirectangular metres. Limits: 6.5 m for NSW ids, 12 m for OSM ids
  (OSM geometry is denser; actual max ~8.7 m at `interval=5`).
- Regression points: `REGRESSION_POINTS` (NSW) and `OSM_REGRESSION_POINTS`
  verify specific coordinates land in the named suburb in both raw and
  simplified geometry. When adding a state, pick coastal/border suburbs from
  the downloaded data and verify membership against the unsimplified geometry.

## Caches

- `--download-cache PATH` — NSW FeatureServer GeoJSON cache. Must be ignored
  (`data/regions/*-download-cache.json`) or outside the repo.
- `--osm-extract PATH` — the `.osm.pbf` extract (default
  `data/regions/australia-osm-download-cache.osm.pbf`, also gitignored).
  Missing file triggers a download of the pinned Geofabrik revision
  (`osm_suburbs.GEOFABRIK_URL`). Bump the pinned filename to refresh data.

## Adding a new Australian state

1. Add its `ISO3166-2` code → Natural Earth state name in `osm_suburbs.STATES`
   (and `REQUIRED_STATES` if coverage is expected).
2. Add regression points to `OSM_REGRESSION_POINTS`.
3. Run `python ios/Scripts/prepare-suburb-boundaries.py`.

## Adding a new country

1. Extend `PARENT` in `prepare-state-boundaries.py` and regenerate states.
2. Choose a suburb-level `admin_level` for that country (see the OSM wiki
   `Tag:boundary=administrative` table) or a national authoritative source.
3. New country extract: point `GEOFABRIK_URL`-equivalent at the country's
   Geofabrik `.osm.pbf`, or extend `osm_suburbs` to take a per-country file.
   Give the new data its own id base if ids can't reuse OSM relation ids.
4. New levels beyond suburb need matching `kind`, `parent` chains, iOS/web
   decoding entries, and metadata keys.

## Known caveats

- OSM AU suburb boundaries originate from the 2020 PSMA import plus manual
  updates; very recent gazetted changes may lag. If fresher authoritative data
  is ever needed, Geoscape Administrative Boundaries (data.gov.au, per-state
  WFS GeoJSON, CC BY 4.0) is the documented alternative — but it would require
  a new id scheme.
- A few OSM localities overlap (e.g. "Perth Cultural Centre" inside "Perth")
  — `coverage_names`/point lookups can legitimately return multiple suburbs.
- The Overpass API is an alternative OSM source, but was unreachable in dev at
  implementation time; the pinned Geofabrik extract is reproducible and fast.
- `update_names` appends to `region-names.json` keyed by id; name changes flow
  through on the next run.
