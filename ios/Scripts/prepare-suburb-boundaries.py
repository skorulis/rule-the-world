from __future__ import annotations

import argparse
import hashlib
import json
import math
import subprocess
from datetime import datetime, timezone
import tempfile
import urllib.parse
import urllib.request
from pathlib import Path

from region_pipeline import (
    OUTPUT, coverage_names, load_regions, publish_dataset, regroup, validate_file, validate_resources, write_level,
)
import osm_suburbs

ROOT = Path(__file__).resolve().parents[2]
LAYER = "https://portal.spatial.nsw.gov.au/server/rest/services/NSW_Administrative_Boundaries_Theme/FeatureServer/2"
PARENT = {"New South Wales": "1159313299"}
LEVELS = {"medium": 5}
OSM_EXTRACT = OUTPUT / "australia-osm-download-cache.osm.pbf"
MAX_DEVIATION_METERS = 6.5
OSM_MAX_DEVIATION_METERS = 12.0  # OSM source geometry is denser; allow more simplification drift
PAGE = 2000
ID_BASE = 9_000_000_000_000  # reserved suburb id range, disjoint from Natural Earth ids
NAMES = ROOT / "ios/RuleTheWorld/Resource/Regions/region-names.json"
REGRESSION_POINTS = [
    {"latitude": -33.8518, "longitude": 151.2645, "name": "Vaucluse", "id": "9000108032101"},
    {"latitude": -33.8632, "longitude": 151.2694, "name": "Rose Bay", "id": "9000108030813"},
    {"latitude": -33.8643, "longitude": 151.2723, "name": "Vaucluse", "id": "9000108032101"},
    {"latitude": -33.8466, "longitude": 151.2812, "name": "Watsons Bay", "id": "9000108033257"},
    {"latitude": -33.8465, "longitude": 151.2821, "name": "Vaucluse", "id": "9000108032101"},
    {"latitude": -33.8410, "longitude": 151.2766, "name": "Watsons Bay", "id": "9000108033257"},
    {"latitude": -33.8692, "longitude": 151.2529, "name": "Rose Bay", "id": "9000108030813"},
    {"latitude": -33.8772, "longitude": 151.2773, "name": "Dover Heights", "id": "9000108029656"},
    {"latitude": -33.8759, "longitude": 151.2778, "name": "Rose Bay", "id": "9000108030813"},
    {"latitude": -33.8793, "longitude": 151.2780, "name": "Dover Heights", "id": "9000108029656"},
]

# Coastal/border membership checks for OSM-sourced suburbs, verified against
# unsimplified relation geometry during ingestion (one or more per state).
OSM_REGRESSION_POINTS = [
    {"latitude": -37.8641, "longitude": 144.9812, "name": "St Kilda", "id": "9200002397474"},
    {"latitude": -38.3438, "longitude": 144.7395, "name": "Sorrento", "id": "9200002451382"},
    {"latitude": -38.5233, "longitude": 143.9213, "name": "Lorne", "id": "9200002732599"},
    {"latitude": -28.1703, "longitude": 153.5305, "name": "Coolangatta", "id": "9200011678057"},
    {"latitude": -26.4001, "longitude": 153.0910, "name": "Noosa Heads", "id": "9200011676220"},
    {"latitude": -16.9178, "longitude": 145.7757, "name": "Cairns City", "id": "9200011677114"},
    {"latitude": -34.9787, "longitude": 138.5138, "name": "Glenelg", "id": "9200009096044"},
    {"latitude": -35.5467, "longitude": 138.6116, "name": "Victor Harbor", "id": "9200007246858"},
    {"latitude": -31.9992, "longitude": 115.7567, "name": "Cottesloe", "id": "9200011689392"},
    {"latitude": -32.0526, "longitude": 115.7609, "name": "Fremantle", "id": "9200011689400"},
    {"latitude": -17.9600, "longitude": 122.2350, "name": "Broome", "id": "9200011690252"},
    {"latitude": -42.8824, "longitude": 147.3258, "name": "Hobart", "id": "9200010625465"},
    {"latitude": -42.9642, "longitude": 147.2881, "name": "Kingston", "id": "9200010625461"},
    {"latitude": -12.4635, "longitude": 130.8436, "name": "Darwin City", "id": "9200011716543"},
    {"latitude": -23.6997, "longitude": 133.8814, "name": "Alice Springs", "id": "9200011716659"},
    {"latitude": -35.2361, "longitude": 149.0678, "name": "Belconnen", "id": "9200006805547"},
    {"latitude": -35.1565, "longitude": 150.6820, "name": "Jervis Bay", "id": "9200011716766"},
]


def query_page(offset: int) -> dict:
    parameters = urllib.parse.urlencode({
        "where": "state = 2",  # NSW
        "outFields": "rid,cadid,suburbname,state",
        "returnGeometry": "true",
        "outSR": "4326",
        "orderByFields": "rid",
        "resultOffset": offset,
        "resultRecordCount": PAGE,
        "f": "geojson",
    })
    return request(parameters)


def request(parameters: str) -> dict:
    with urllib.request.urlopen(f"{LAYER}/query?{parameters}", timeout=180) as response:
        result = json.loads(response.read())
    assert "error" not in result, result
    return result


def source_count() -> int:
    result = request(urllib.parse.urlencode({"where": "state = 2", "returnCountOnly": "true", "f": "json"}))
    assert isinstance(result.get("count"), int) and result["count"] > 0, result
    return result["count"]


def download_suburbs() -> dict:
    expected = source_count()
    features = []
    while len(features) < expected:
        page = query_page(len(features))
        assert page.get("type") == "FeatureCollection" and page.get("features"), page
        features.extend(page["features"])
        print(f"Downloaded {len(features)}/{expected} suburbs", flush=True)
    assert len(features) == expected == source_count(), "source changed during download"
    assert len({feature["properties"]["rid"] for feature in features}) == expected, "duplicate source rows"
    return {"type": "FeatureCollection", "features": features}


def osm_collection(extract: Path) -> dict:
    suburbs, borders = osm_suburbs.collect_suburbs(extract)
    state_ids = {feature["properties"]["name"]: feature["properties"]["id"] for feature in load_regions("states")["features"]}
    collection, skipped, states_found = osm_suburbs.normalize(suburbs, borders, state_ids)
    missing = set(osm_suburbs.STATES.values()) - states_found
    assert not missing, f"admin_level=4 borders missing from extract: {missing}"
    expected_parents = {state_ids[name] for code, name in osm_suburbs.STATES.items() if code in osm_suburbs.REQUIRED_STATES}
    actual_parents = {feature["properties"]["parent"] for feature in collection["features"]}
    missing_parents = expected_parents - actual_parents
    assert not missing_parents, f"no suburbs for states: {missing_parents}"
    if skipped:
        print(f"Skipped {len(skipped)} OSM suburbs outside collected state borders: {[name for _, name in skipped][:10]}")
    print(f"Normalized {len(collection['features'])} OpenStreetMap suburbs across {len(actual_parents)} states")
    return collection


def normalize(collection: dict) -> dict:
    seen = set()
    features = []
    for feature in collection["features"]:
        properties = feature["properties"]
        cadid = properties.get("cadid")
        name = (properties.get("suburbname") or "").strip()
        assert cadid and name and feature["geometry"], properties
        assert cadid not in seen, f"duplicate cadid {cadid}"
        seen.add(cadid)
        identity = str(ID_BASE + int(cadid))
        if name.isupper():
            name = name.title()
        features.append({
            "type": "Feature",
            "properties": {
                "id": identity, "name": name, "kind": "suburb",
                "parent": PARENT["New South Wales"],
            },
            "geometry": feature["geometry"],
        })
    features.sort(key=lambda feature: feature["properties"]["id"])
    return {"type": "FeatureCollection", "features": features}


def simplify_geojson(directory: Path, source: Path, interval: int, target: Path):
    subprocess.run([
        "npx", "--yes", "mapshaper@0.7.101", "-i", str(source),
        "-simplify", "dp", f"interval={interval}", "keep-shapes",
        "-o", str(target), "format=geojson", "precision=0.000001",
    ], check=True, cwd=directory)


def repair_invalid(collection: dict) -> int:
    """Repair invalid simplified geometries; may split parts but never drops them."""
    from shapely.geometry import MultiPolygon, Polygon, mapping, shape
    from shapely.validation import make_valid

    def rounded(geometry):
        return json.loads(json.dumps(mapping(geometry)), parse_float=lambda value: round(float(value), 6))

    repaired = 0
    for feature in collection["features"]:
        geometry = shape(feature["geometry"])
        if geometry.is_valid:
            continue
        for _ in range(4):
            # Re-round after each make_valid: rounding can re-break tiny rings.
            geometry = shape(rounded(make_valid(geometry)))
            if geometry.is_valid:
                break
        assert geometry.is_valid, f"could not repair simplified geometry: {feature['properties']}"
        parts = [part for geom in ([geometry] if geometry.geom_type != "GeometryCollection" else geometry.geoms)
                 for part in (list(geom.geoms) if geom.geom_type == "MultiPolygon" else [geom])
                 if part.geom_type == "Polygon"]
        feature["geometry"] = rounded(MultiPolygon(parts))
        assert shape(feature["geometry"]).is_valid, f"rounded repair invalid: {feature['properties']}"
        repaired += 1
    return repaired


def update_names(collection: dict):
    names = json.loads(NAMES.read_text())
    for feature in collection["features"]:
        properties = feature["properties"]
        names[properties["id"]] = properties["name"]
    NAMES.write_text(json.dumps(dict(sorted(names.items())), indent=2, ensure_ascii=False) + "\n")


def geometry_quality(source: dict, output: dict) -> dict:
    from shapely.affinity import scale
    from shapely.geometry import Point, shape

    originals = {feature["properties"]["id"]: feature for feature in source["features"]}
    assert set(originals) == {feature["properties"]["id"] for feature in output["features"]}
    maximum = 0
    vertices = 0
    source_invalid = 0
    output_invalid = 0
    holes = 0
    for feature in output["features"]:
        original = originals[feature["properties"]["id"]]
        assert original["properties"] == feature["properties"]
        raw = shape(original["geometry"])
        reduced = shape(feature["geometry"])
        raw_parts = list(raw.geoms) if raw.geom_type == "MultiPolygon" else [raw]
        parts = list(reduced.geoms) if reduced.geom_type == "MultiPolygon" else [reduced]
        assert len(parts) >= len(raw_parts), f"lost polygon part: {feature['properties']}"
        assert sum(len(part.interiors) for part in parts) >= sum(len(part.interiors) for part in raw_parts), feature["properties"]
        assert reduced.is_valid or not raw.is_valid, f"introduced invalid geometry: {feature['properties']}"
        source_invalid += not raw.is_valid
        output_invalid += not reduced.is_valid
        holes += sum(len(part.interiors) for part in parts)
        for point in REGRESSION_POINTS + OSM_REGRESSION_POINTS:
            if point["id"] == feature["properties"]["id"]:
                coordinate = Point(point["longitude"], point["latitude"])
                assert original["properties"]["name"] == point["name"] and raw.contains(coordinate), point
                assert reduced.contains(coordinate), point
        latitude = raw.centroid.y
        x_scale = 111195 * math.cos(math.radians(latitude))
        projected = [scale(geometry, xfact=x_scale, yfact=111195, origin=(0, 0)) for geometry in (raw, reduced)]
        deviation = projected[0].boundary.hausdorff_distance(projected[1].boundary)
        maximum = max(maximum, deviation)
        allowed = MAX_DEVIATION_METERS if int(feature["properties"]["id"]) < osm_suburbs.OSM_ID_BASE else OSM_MAX_DEVIATION_METERS
        assert deviation <= allowed, f"{feature['properties']}: {deviation:.2f} m deviation"
        vertices += sum(len(part.exterior.coords) + sum(len(ring.coords) for ring in part.interiors) for part in raw_parts)
    return {
        "rawVertices": vertices,
        "holes": holes,
        "sourceInvalidFeatures": source_invalid,
        "outputInvalidFeatures": output_invalid,
        "maxBoundaryHausdorffMeters": round(maximum, 3),
        "maximumAllowedMeters": MAX_DEVIATION_METERS,
        "maximumAllowedOsmMeters": OSM_MAX_DEVIATION_METERS,
        "measurement": "discrete symmetric boundary Hausdorff distance in per-feature local equirectangular metres",
    }


def prepare(cache: Path | None = None, osm_extract: Path = OSM_EXTRACT):
    if cache and ROOT in cache.resolve().parents:
        assert cache.resolve().parent == OUTPUT and cache.name.endswith("-download-cache.json"), "use an ignored data/regions/*-download-cache.json or a cache outside the repository"
    OUTPUT.mkdir(parents=True, exist_ok=True)
    if not osm_extract.exists():
        print(f"Downloading {osm_suburbs.GEOFABRIK_URL}", flush=True)
        osm_suburbs.download(osm_suburbs.GEOFABRIK_URL, osm_extract)
    metadata = {
        "source": "NSW Administrative Boundaries Theme - Suburb (FeatureServer layer 2); OpenStreetMap (all other Australian states/territories)",
        "url": LAYER,
        "license": "Creative Commons Attribution; Open Data Commons Open Database License (OSM portions)",
        "licenseURL": "https://data.nsw.gov.au/data/dataset/nsw-foundation-spatial-data-framework-administrative-boundaries-suburb",
        "sources": [
            {
                "name": "NSW Administrative Boundaries Theme - Suburb (FeatureServer layer 2)",
                "url": LAYER,
                "license": "Creative Commons Attribution",
                "licenseURL": "https://data.nsw.gov.au/data/dataset/nsw-foundation-spatial-data-framework-administrative-boundaries-suburb",
                "states": ["New South Wales"],
                "idBase": ID_BASE,
                "idScheme": "idBase + source cadid",
            },
            {
                "name": "OpenStreetMap administrative boundaries via Geofabrik Australia extract",
                "url": osm_suburbs.GEOFABRIK_URL,
                "license": "Open Data Commons Open Database License 1.0",
                "licenseURL": "https://opendatacommons.org/licenses/odbl/1-0/",
                "attribution": "© OpenStreetMap contributors",
                "states": sorted(osm_suburbs.STATES.values()),
                "adminLevels": sorted(osm_suburbs.SUBURB_ADMIN_LEVELS, key=int),
                "idBase": osm_suburbs.OSM_ID_BASE,
                "idScheme": "idBase + OSM relation id",
            },
        ],
        "tool": "mapshaper@0.7.101",
        "simplification": "spherical Douglas-Peucker; shared topology; keep-shapes",
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "precisionDegrees": 0.000001,
        "idBase": ID_BASE,
        "parents": {},
        "regressionPoints": REGRESSION_POINTS + OSM_REGRESSION_POINTS,
        "regressionPointSource": "Membership verified against unsimplified source geometry",
        "levels": {},
    }
    with tempfile.TemporaryDirectory() as temporary:
        directory = Path(temporary)
        raw = directory / "suburbs.geojson"
        if cache and cache.exists():
            downloaded = json.loads(cache.read_text())
            assert len(downloaded["features"]) == source_count(), "cached source count differs from service"
        else:
            downloaded = download_suburbs()
            if cache:
                cache.write_text(json.dumps(downloaded, separators=(",", ":")))
        collection = normalize(downloaded)
        osm = osm_collection(osm_extract)
        extract_data = osm_extract.read_bytes()
        metadata["sources"][1]["extract"] = {"bytes": len(extract_data), "sha256": hashlib.sha256(extract_data).hexdigest()}
        merged = collection["features"] + osm["features"]
        seen = set()
        for feature in merged:
            assert feature["properties"]["id"] not in seen, feature["properties"]["id"]
            seen.add(feature["properties"]["id"])
        merged.sort(key=lambda feature: feature["properties"]["id"])
        collection = {"type": "FeatureCollection", "features": merged}
        state_names = {feature["properties"]["id"]: feature["properties"]["name"] for feature in load_regions("states")["features"]}
        parents = {state_names[parent]: parent for parent in {feature["properties"]["parent"] for feature in merged}}
        metadata["parents"] = dict(sorted(parents.items()))
        source_data = json.dumps(collection, separators=(",", ":")).encode()
        raw.write_bytes(source_data)
        metadata["normalizedSource"] = {
            "bytes": len(source_data), "sha256": hashlib.sha256(source_data).hexdigest(),
            "suburbs": len(collection["features"]),
        }
        print(f"Normalized {len(collection['features'])} suburbs", flush=True)
        for level, interval in LEVELS.items():
            target = directory / f"{level}.geojson"
            simplify_geojson(directory, raw, interval, target)
            simplified = json.loads(target.read_text())
            regroup(simplified)
            repaired = repair_invalid(simplified)
            if repaired:
                print(f"Repaired {repaired} invalid simplified geometries", flush=True)
            stats = write_level(simplified, "suburbs", level, interval, "suburbs", output=directory)
            decoded = load_regions("suburbs", level, output=directory)
            quality = geometry_quality(collection, decoded)
            metadata["levels"][level] = {**stats, **quality}
            print(level, metadata["levels"][level], flush=True)
        publish_dataset("suburbs", metadata, directory)
        update_names(decoded)


def validate():
    metadata = json.loads((OUTPUT / "suburbs-source.json").read_text())
    states = {feature["properties"]["id"] for feature in load_regions("states")["features"]}
    assert set(metadata["parents"].values()) <= states
    countries = {feature["properties"]["id"] for feature in load_regions("countries")["features"]}
    validate_resources("suburbs", metadata)
    for level in LEVELS:
        assert metadata["levels"][level]["intervalMeters"] == LEVELS[level]
        assert metadata["levels"][level]["maxBoundaryHausdorffMeters"] <= OSM_MAX_DEVIATION_METERS
        ids, parts, vertices = validate_file("suburbs", level, metadata["levels"][level], "suburbs")
        print(f"Validated {level}: {len(ids)} suburbs, {parts} parts, {vertices} vertices")
        assert not ids & states and not ids & countries, "suburb ids must not collide"
        assert all(int(identity) >= metadata["idBase"] for identity in ids)
        for feature in load_regions("suburbs", level)["features"]:
            assert feature["properties"]["parent"] in states
        if level == "medium":
            collection = load_regions("suburbs", level)
            for latitude, longitude in [(-33.898, 151.179), (-33.868, 151.209), (-32.927, 151.776)]:
                print(f"  Coverage at {latitude}, {longitude}: {coverage_names(collection, latitude, longitude)}")
            for point in REGRESSION_POINTS + OSM_REGRESSION_POINTS:
                assert coverage_names(collection, point["latitude"], point["longitude"]) == [point["name"]], point
            print(f"  Verified {len(REGRESSION_POINTS) + len(OSM_REGRESSION_POINTS)} source-derived coastal regression points")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--download-cache", type=Path)
    parser.add_argument("--osm-extract", type=Path, default=OSM_EXTRACT)
    arguments = parser.parse_args()
    if not arguments.validate_only:
        prepare(arguments.download_cache, arguments.osm_extract)
    validate()
