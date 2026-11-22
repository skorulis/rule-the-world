import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import urllib.request

import geobuf

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


def encode_collection(collection: dict) -> bytes:
    data = geobuf.encode(collection, 6, 2)
    assert geobuf.decode(data) == collection, "Geobuf round trip changed geometry or properties"
    assert data == geobuf.encode(collection, 6, 2), "nondeterministic encoding"
    return data


def write_level(collection: dict, stem: str, level: str, interval: int, regions_key: str, output: Path = OUTPUT):
    identities, parts, vertices = expand_antimeridian(collection)
    source = (json.dumps(collection, separators=(",", ":"), ensure_ascii=False) + "\n").encode()
    data = encode_collection(collection)
    (output / f"{stem}-{level}.pbf").write_bytes(data)
    return {
        "intervalMeters": interval, regions_key: len(identities), "polygonParts": parts,
        "vertices": vertices, "format": "geobuf", "precisionDegrees": 0.000001,
        "geojsonBytes": len(source), "bytes": len(data),
        "reductionPercent": round(100 * (1 - len(data) / len(source)), 2),
        "sha256": hashlib.sha256(data).hexdigest(),
    }


def validate_file(stem: str, level: str, expected: dict, regions_key: str, output: Path = OUTPUT):
    data = (output / f"{stem}-{level}.pbf").read_bytes()
    assert expected["format"] == "geobuf" and len(data) == expected["bytes"]
    assert hashlib.sha256(data).hexdigest() == expected["sha256"]
    collection = geobuf.decode(data)
    assert collection["type"] == "FeatureCollection" and collection["features"]
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


def load_regions(stem: str, level: str = "medium", output: Path = OUTPUT):
    return geobuf.decode((output / f"{stem}-{level}.pbf").read_bytes())


def atomic_write(target: Path, data: bytes):
    with tempfile.NamedTemporaryFile(dir=target.parent, delete=False) as temporary:
        temporary.write(data)
        path = Path(temporary.name)
    path.chmod(0o644)
    path.replace(target)


def publish_dataset(stem: str, metadata: dict, staging: Path):
    levels = [validate_file(stem, level, expected, stem, output=staging) for level, expected in metadata["levels"].items()]
    assert levels and all((ids, parts) == levels[0][:2] for ids, parts, _ in levels), "region IDs or parts differ between levels"
    if stem != "countries":
        parent_stem = "countries" if stem == "states" else "states"
        parents = {feature["properties"]["id"] for feature in load_regions(parent_stem)["features"]}
        ancestors = {feature["properties"]["id"] for feature in load_regions("countries")["features"]}
        for level in metadata["levels"]:
            collection = load_regions(stem, level, output=staging)
            for feature in collection["features"]:
                properties = feature["properties"]
                assert properties["parent"] in parents and properties["id"] not in parents | ancestors
                assert properties["kind"] == ("state" if stem == "states" else "suburb")
    for level in metadata["levels"]:
        filename = f"{stem}-{level}.pbf"
        atomic_write(OUTPUT / filename, (staging / filename).read_bytes())
    atomic_write(OUTPUT / f"{stem}-source.json", (json.dumps(metadata, indent=2) + "\n").encode())
    synchronize(stem, metadata)


def synchronize(stem: str, metadata: dict):
    bundle = ROOT / "ios/RuleTheWorld/Resource/Regions"
    web = ROOT / "web/data/regions"
    bundled_levels = {"countries": {"medium", "coarse"}, "states": {"coarse"}, "suburbs": {"medium"}}
    filenames = [f"{stem}-{level}.pbf" for level in metadata["levels"] if level in bundled_levels[stem]]
    filenames.append(f"{stem}-source.json")
    for filename in filenames:
        source = OUTPUT / filename
        target = bundle / filename
        if source.resolve() != target.resolve():
            atomic_write(target, source.read_bytes())
    if "medium" in metadata["levels"]:
        target = web / f"{stem}-medium.pbf"
        relative = f"../../../data/regions/{target.name}"
        if not target.is_symlink():
            assert not target.exists(), f"refusing to replace {target}"
            target.symlink_to(relative)
        assert target.resolve() == (OUTPUT / target.name).resolve(), f"stale web resource: {target}"


def validate_resources(stem: str, metadata: dict):
    bundle = ROOT / "ios/RuleTheWorld/Resource/Regions"
    for level in metadata["levels"]:
        filename = f"{stem}-{level}.pbf"
        if stem == "countries" or (stem == "states" and level == "coarse") or stem == "suburbs":
            assert (OUTPUT / filename).read_bytes() == (bundle / filename).read_bytes(), f"stale iOS resource: {filename}"
        if level == "medium":
            assert (OUTPUT / filename).read_bytes() == (ROOT / "web/data/regions" / filename).read_bytes()
    filename = f"{stem}-source.json"
    assert (OUTPUT / filename).read_bytes() == (bundle / filename).read_bytes()


def convert_existing():
    for stem in ("countries", "states", "suburbs"):
        metadata = json.loads((OUTPUT / f"{stem}-source.json").read_text())
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            for level, previous in metadata["levels"].items():
                collection = json.loads((OUTPUT / f"{stem}-{level}.geojson").read_text())
                stats = write_level(collection, stem, level, previous["intervalMeters"], stem, output=directory)
                for key in (stem, "polygonParts", "vertices"):
                    assert stats[key] == previous[key], f"changed {stem} {level} {key}"
                metadata["levels"][level] = {**previous, **stats}
                decoded = load_regions(stem, level, output=directory)
                for point in metadata.get("regressionPoints", []):
                    assert coverage_names(decoded, point["latitude"], point["longitude"]) == [point["name"]], point
                print(f"{stem}-{level}: {stats['geojsonBytes']:,} -> {stats['bytes']:,} bytes ({stats['reductionPercent']}% smaller)")
            publish_dataset(stem, metadata, directory)
        validate_resources(stem, metadata)


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


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--convert-existing", action="store_true", required=True)
    parser.parse_args()
    convert_existing()
