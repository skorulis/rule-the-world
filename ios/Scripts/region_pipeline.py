import hashlib
import json
from pathlib import Path
import subprocess
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "data/regions"
REVISION = "9380cca83db5f9aef52d5e762765100745f84b27"
TOOL = "mapshaper@0.7.101"
LEVELS = {"medium": 3000, "coarse": 15000}


def download(directory: Path, source: str, stem: str):
    for extension in ("shp", "shx", "dbf", "prj"):
        with urllib.request.urlopen(f"{source}.{extension}") as response:
            (directory / f"{stem}.{extension}").write_bytes(response.read())


def simplify(directory: Path, stem: str, each: str, fields: str, interval: int, target: Path, where: str = "id != null"):
    subprocess.run([
        "npx", "--yes", TOOL, "-i", str(directory / f"{stem}.shp"),
        "-each", each,
        "-filter", where,
        "-filter-fields", fields, "-explode",
        "-simplify", f"interval={interval}", "keep-shapes",
        "-o", str(target), "format=geojson", "precision=0.00001",
    ], check=True)


def regroup(collection: dict):
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


def expand_antimeridian(collection: dict):
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
    return identities, parts, vertices


def write_level(collection: dict, stem: str, level: str, interval: int, regions_key: str):
    identities, parts, vertices = expand_antimeridian(collection)
    data = (json.dumps(collection, separators=(",", ":"), ensure_ascii=False) + "\n").encode()
    (OUTPUT / f"{stem}-{level}.geojson").write_bytes(data)
    return {
        "intervalMeters": interval, regions_key: len(identities), "polygonParts": parts,
        "vertices": vertices, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
    }


def validate_file(stem: str, level: str, expected: dict, regions_key: str):
    data = (OUTPUT / f"{stem}-{level}.geojson").read_bytes()
    assert hashlib.sha256(data).hexdigest() == expected["sha256"]
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
    assert len(ids) == expected[regions_key]
    assert parts == expected["polygonParts"]
    assert vertices == expected["vertices"]
    return ids, parts, vertices


def load_regions(stem: str, level: str = "medium"):
    return json.loads((OUTPUT / f"{stem}-{level}.geojson").read_text())


def coverage_names(collection: dict, latitude: float, longitude: float):
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
    return names
