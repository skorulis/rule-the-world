import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "data/regions"
REVISION = "9380cca83db5f9aef52d5e762765100745f84b27"
SOURCE = f"https://raw.githubusercontent.com/nvkelso/natural-earth-vector/{REVISION}/50m_cultural/ne_50m_admin_0_countries"
TOOL = "mapshaper@0.7.101"
LEVELS = {"medium": 3000, "coarse": 15000}


def prepare():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    metadata = {
        "source": "Natural Earth Admin 0 Countries, 1:50 million",
        "version": "5.1.1",
        "revision": REVISION,
        "url": "https://www.naturalearthdata.com/downloads/50m-cultural-vectors/50m-admin-0-countries-2/",
        "license": "Public domain",
        "licenseURL": "https://www.naturalearthdata.com/about/terms-of-use/",
        "tool": TOOL,
        "simplification": "spherical weighted Visvalingam; exploded parts with keep-shapes; shared topology",
        "precisionDegrees": 0.00001,
        "levels": {},
    }
    with tempfile.TemporaryDirectory() as temporary:
        directory = Path(temporary)
        for extension in ("shp", "shx", "dbf", "prj"):
            with urllib.request.urlopen(f"{SOURCE}.{extension}") as response:
                (directory / f"countries.{extension}").write_bytes(response.read())
        for level, interval in LEVELS.items():
            target = directory / f"{level}.geojson"
            subprocess.run([
                "npx", "--yes", TOOL, "-i", str(directory / "countries.shp"),
                "-each", 'id=String(NE_ID),name=NAME_EN,kind="country"',
                "-filter-fields", "id,name,kind", "-explode",
                "-simplify", f"interval={interval}", "keep-shapes",
                "-o", str(target), "format=geojson", "precision=0.00001",
            ], check=True)
            collection = json.loads(target.read_text())
            grouped = {}
            for feature in collection["features"]:
                identity = feature["properties"]["id"]
                if identity not in grouped:
                    grouped[identity] = {
                        "type": "Feature", "properties": feature["properties"],
                        "geometry": {"type": "MultiPolygon", "coordinates": []},
                    }
                geometry = feature["geometry"]
                polygons = geometry["coordinates"] if geometry["type"] == "MultiPolygon" else [geometry["coordinates"]]
                grouped[identity]["geometry"]["coordinates"].extend(polygons)
            collection["features"] = sorted(grouped.values(), key=lambda feature: feature["properties"]["id"])
            vertices = 0
            parts = 0
            identities = set()
            for feature in collection["features"]:
                identity = feature["properties"]["id"]
                assert identity not in identities and identity != "undefined"
                identities.add(identity)
                geometry = feature["geometry"]
                polygons = geometry["coordinates"] if geometry["type"] == "MultiPolygon" else [geometry["coordinates"]]
                parts += len(polygons)
                for polygon in polygons:
                    for ring in polygon:
                        assert len(ring) >= 4 and ring[0] == ring[-1]
                        expanded = [ring[0]]
                        for point in ring[1:]:
                            previous = expanded[-1]
                            distance = abs(point[0] - previous[0])
                            if distance > 180:
                                assert previous[1] <= -85 and point[1] <= -85
                                steps = int(distance / 90) + 1
                                for step in range(1, steps):
                                    expanded.append([
                                        round(previous[0] + (point[0] - previous[0]) * step / steps, 5),
                                        round(previous[1] + (point[1] - previous[1]) * step / steps, 5),
                                    ])
                            expanded.append(point)
                        ring[:] = expanded
                        assert all(-180 <= x <= 180 and -90 <= y <= 90 for x, y in ring)
                        assert all(abs(a[0] - b[0]) <= 180 for a, b in zip(ring, ring[1:]))
                        vertices += len(ring)
            data = (json.dumps(collection, separators=(",", ":"), ensure_ascii=False) + "\n").encode()
            (OUTPUT / f"countries-{level}.geojson").write_bytes(data)
            metadata["levels"][level] = {
                "intervalMeters": interval, "countries": len(identities), "polygonParts": parts,
                "vertices": vertices, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
            }
            print(level, metadata["levels"][level])
    (OUTPUT / "countries-source.json").write_text(json.dumps(metadata, indent=2) + "\n")


def validate():
    metadata = json.loads((OUTPUT / "countries-source.json").read_text())
    identities = []
    part_counts = []
    for level in LEVELS:
        data = (OUTPUT / f"countries-{level}.geojson").read_bytes()
        assert hashlib.sha256(data).hexdigest() == metadata["levels"][level]["sha256"]
        collection = json.loads(data)
        ids = set()
        parts = 0
        vertices = 0
        for feature in collection["features"]:
            identity = feature["properties"]["id"]
            assert identity not in ids
            ids.add(identity)
            for polygon in feature["geometry"]["coordinates"]:
                parts += 1
                for ring in polygon:
                    assert len(ring) >= 4 and ring[0] == ring[-1]
                    assert all(-180 <= x <= 180 and -90 <= y <= 90 for x, y in ring)
                    assert all(abs(a[0] - b[0]) <= 180 for a, b in zip(ring, ring[1:]))
                    vertices += len(ring)
        assert len(ids) == metadata["levels"][level]["countries"]
        assert parts == metadata["levels"][level]["polygonParts"]
        assert vertices == metadata["levels"][level]["vertices"]
        identities.append(ids)
        part_counts.append(parts)
        print(f"Validated {level}: {len(ids)} countries, {parts} parts, {vertices} vertices, {len(data)} bytes")
        if level == "medium":
            for latitude, longitude in [(-25, 134), (48.85, 2.35), (46.8, 8.2), (-17.8, 178), (-16.8, -179.9), (0, -140)]:
                names = []
                for feature in collection["features"]:
                    for polygon in feature["geometry"]["coordinates"]:
                        coverage = []
                        for ring in polygon:
                            inside = False
                            for (ax, ay), (bx, by) in zip(ring, ring[1:]):
                                if (ay > latitude) != (by > latitude) and longitude < ax + (latitude - ay) * (bx - ax) / (by - ay):
                                    inside = not inside
                            coverage.append(inside)
                        if coverage[0] and not any(coverage[1:]):
                            names.append(feature["properties"]["name"])
                            break
                print(f"  Coverage at {latitude}, {longitude}: {names}")
    assert identities[0] == identities[1] and part_counts[0] == part_counts[1]


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--validate-only", action="store_true")
    arguments = parser.parse_args()
    if not arguments.validate_only:
        prepare()
    validate()
