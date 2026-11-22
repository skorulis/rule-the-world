import argparse
import json
import subprocess
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
LEVELS = {"medium": 100}
PAGE = 2000
ID_BASE = 9_000_000_000_000  # reserved suburb id range, disjoint from Natural Earth ids
NAMES = ROOT / "ios/RuleTheWorld/Resource/Regions/region-names.json"


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
    with urllib.request.urlopen(f"{LAYER}/query?{parameters}") as response:
        return json.loads(response.read())


def download_suburbs() -> dict:
    features = []
    offset = 0
    while True:
        page = query_page(offset)
        assert page.get("type") == "FeatureCollection", page
        features.extend(page["features"])
        if len(page["features"]) < PAGE:
            break
        offset += PAGE
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
        "-simplify", f"interval={interval}", "keep-shapes",
        "-o", str(target), "format=geojson", "precision=0.00001",
    ], check=True, cwd=directory)


def update_names(collection: dict):
    names = json.loads(NAMES.read_text())
    for feature in collection["features"]:
        properties = feature["properties"]
        names[properties["id"]] = properties["name"]
    NAMES.write_text(json.dumps(dict(sorted(names.items())), indent=2, ensure_ascii=False) + "\n")


def prepare():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    metadata = {
        "source": "NSW Administrative Boundaries Theme - Suburb (FeatureServer layer 2)",
        "url": LAYER,
        "license": "Creative Commons Attribution",
        "licenseURL": "https://data.nsw.gov.au/data/dataset/nsw-foundation-spatial-data-framework-administrative-boundaries-suburb",
        "tool": "mapshaper@0.7.101",
        "simplification": "spherical weighted Visvalingam; keep-shapes",
        "precisionDegrees": 0.00001,
        "idBase": ID_BASE,
        "parents": PARENT,
        "levels": {},
    }
    with tempfile.TemporaryDirectory() as temporary:
        directory = Path(temporary)
        raw = directory / "suburbs.geojson"
        collection = normalize(download_suburbs())
        raw.write_text(json.dumps(collection))
        print(f"Downloaded {len(collection['features'])} suburbs")
        for level, interval in LEVELS.items():
            target = directory / f"{level}.geojson"
            simplify_geojson(directory, raw, interval, target)
            simplified = json.loads(target.read_text())
            regroup(simplified)
            update_names(simplified)
            metadata["levels"][level] = write_level(simplified, "suburbs", level, interval, "suburbs")
            print(level, metadata["levels"][level])
    (OUTPUT / "suburbs-source.json").write_text(json.dumps(metadata, indent=2) + "\n")


def validate():
    metadata = json.loads((OUTPUT / "suburbs-source.json").read_text())
    states = {feature["properties"]["id"] for feature in load_regions("states")["features"]}
    assert set(metadata["parents"].values()) <= states
    countries = {feature["properties"]["id"] for feature in load_regions("countries")["features"]}
    for level in LEVELS:
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


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--validate-only", action="store_true")
    arguments = parser.parse_args()
    if not arguments.validate_only:
        prepare()
    validate()
