from __future__ import annotations

import argparse
import hashlib
import json
import math
import shutil
import subprocess
from datetime import datetime, timezone
import tempfile
import urllib.parse
import urllib.request
from pathlib import Path

from region_pipeline import (
    OUTPUT, coverage_names, load_regions, regroup, validate_file, write_level,
)

ROOT = Path(__file__).resolve().parents[2]
LAYER = "https://portal.spatial.nsw.gov.au/server/rest/services/NSW_Administrative_Boundaries_Theme/FeatureServer/2"
PARENT = {"New South Wales": "1159313299"}
LEVELS = {"medium": 5}
MAX_DEVIATION_METERS = 6.5
BUNDLE = ROOT / "ios/RuleTheWorld/Resource/Regions"
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
        assert len(raw_parts) == len(parts), f"lost polygon part: {feature['properties']}"
        assert sum(len(part.interiors) for part in raw_parts) == sum(len(part.interiors) for part in parts), feature["properties"]
        assert reduced.is_valid or not raw.is_valid, f"introduced invalid geometry: {feature['properties']}"
        source_invalid += not raw.is_valid
        output_invalid += not reduced.is_valid
        holes += sum(len(part.interiors) for part in parts)
        for point in REGRESSION_POINTS:
            if point["id"] == feature["properties"]["id"]:
                coordinate = Point(point["longitude"], point["latitude"])
                assert original["properties"]["name"] == point["name"] and raw.contains(coordinate), point
                assert reduced.contains(coordinate), point
        latitude = raw.centroid.y
        x_scale = 111195 * math.cos(math.radians(latitude))
        projected = [scale(geometry, xfact=x_scale, yfact=111195, origin=(0, 0)) for geometry in (raw, reduced)]
        deviation = projected[0].boundary.hausdorff_distance(projected[1].boundary)
        maximum = max(maximum, deviation)
        assert deviation <= MAX_DEVIATION_METERS, f"{feature['properties']}: {deviation:.2f} m deviation"
        vertices += sum(len(part.exterior.coords) + sum(len(ring.coords) for ring in part.interiors) for part in raw_parts)
    return {
        "rawVertices": vertices,
        "holes": holes,
        "sourceInvalidFeatures": source_invalid,
        "outputInvalidFeatures": output_invalid,
        "maxBoundaryHausdorffMeters": round(maximum, 3),
        "maximumAllowedMeters": MAX_DEVIATION_METERS,
        "measurement": "discrete symmetric boundary Hausdorff distance in per-feature local equirectangular metres",
    }


def prepare(cache: Path | None = None):
    OUTPUT.mkdir(parents=True, exist_ok=True)
    metadata = {
        "source": "NSW Administrative Boundaries Theme - Suburb (FeatureServer layer 2)",
        "url": LAYER,
        "license": "Creative Commons Attribution",
        "licenseURL": "https://data.nsw.gov.au/data/dataset/nsw-foundation-spatial-data-framework-administrative-boundaries-suburb",
        "tool": "mapshaper@0.7.101",
        "simplification": "spherical Douglas-Peucker; shared topology; keep-shapes",
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "precisionDegrees": 0.000001,
        "idBase": ID_BASE,
        "parents": PARENT,
        "regressionPoints": REGRESSION_POINTS,
        "regressionPointSource": "Membership verified against unsimplified NSW source geometry",
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
            quality = geometry_quality(collection, simplified)
            update_names(simplified)
            metadata["levels"][level] = {
                **write_level(simplified, "suburbs", level, interval, "suburbs"), **quality,
            }
            print(level, metadata["levels"][level], flush=True)
    (OUTPUT / "suburbs-source.json").write_text(json.dumps(metadata, indent=2) + "\n")
    for filename in [*(f"suburbs-{level}.geojson" for level in LEVELS), "suburbs-source.json"]:
        shutil.copyfile(OUTPUT / filename, BUNDLE / filename)


def validate():
    metadata = json.loads((OUTPUT / "suburbs-source.json").read_text())
    states = {feature["properties"]["id"] for feature in load_regions("states")["features"]}
    assert set(metadata["parents"].values()) <= states
    countries = {feature["properties"]["id"] for feature in load_regions("countries")["features"]}
    for filename in [*(f"suburbs-{level}.geojson" for level in LEVELS), "suburbs-source.json"]:
        assert (OUTPUT / filename).read_bytes() == (BUNDLE / filename).read_bytes(), f"stale iOS resource: {filename}"
    for level in LEVELS:
        assert metadata["levels"][level]["intervalMeters"] == LEVELS[level]
        assert metadata["levels"][level]["maxBoundaryHausdorffMeters"] <= MAX_DEVIATION_METERS
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
            for point in REGRESSION_POINTS:
                assert coverage_names(collection, point["latitude"], point["longitude"]) == [point["name"]], point
            print(f"  Verified {len(REGRESSION_POINTS)} source-derived coastal regression points")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--download-cache", type=Path)
    arguments = parser.parse_args()
    if not arguments.validate_only:
        prepare(arguments.download_cache)
    validate()
