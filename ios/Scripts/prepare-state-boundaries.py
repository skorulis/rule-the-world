import argparse
import json
import tempfile
from pathlib import Path

from region_pipeline import (
    OUTPUT, REVISION, coverage_names, download, load_regions, regroup,
    simplify, validate_file, write_level,
)

SOURCE = f"https://raw.githubusercontent.com/nvkelso/natural-earth-vector/{REVISION}/10m_cultural/ne_10m_admin_1_states_provinces"
PARENT = {"Australia": "1159320355"}
LEVELS = {"medium": 500, "coarse": 3000}


def each_expression():
    cases = " ".join(f"geonunit == '{name}' ? '{identity}' : null" for name, identity in PARENT.items())
    return f'id=String(ne_id),name=name_en,kind="state",parent={cases}'


def prepare():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    metadata = {
        "source": "Natural Earth Admin 1 States/Provinces, 1:10 million",
        "version": "5.1.1",
        "revision": REVISION,
        "url": "https://www.naturalearthdata.com/downloads/10m-cultural-vectors/10m-admin-1-states-provinces/",
        "license": "Public domain",
        "licenseURL": "https://www.naturalearthdata.com/about/terms-of-use/",
        "tool": "mapshaper@0.7.101",
        "simplification": "spherical weighted Visvalingam; exploded parts with keep-shapes; shared topology",
        "precisionDegrees": 0.00001,
        "parents": PARENT,
        "levels": {},
    }
    with tempfile.TemporaryDirectory() as temporary:
        directory = Path(temporary)
        download(directory, SOURCE, "states")
        for level, interval in LEVELS.items():
            target = directory / f"{level}.geojson"
            simplify(directory, "states", each_expression(), "id,name,kind,parent", interval, target, where="parent != null")
            collection = json.loads(target.read_text())
            regroup(collection)
            metadata["levels"][level] = write_level(collection, "states", level, interval, "states")
            print(level, metadata["levels"][level])
    (OUTPUT / "states-source.json").write_text(json.dumps(metadata, indent=2) + "\n")


def validate():
    metadata = json.loads((OUTPUT / "states-source.json").read_text())
    countries = {feature["properties"]["id"] for feature in load_regions("countries")["features"]}
    assert set(metadata["parents"].values()) <= countries
    identities = []
    part_counts = []
    parents = set()
    for level in LEVELS:
        ids, parts, vertices = validate_file("states", level, metadata["levels"][level], "states")
        identities.append(ids)
        part_counts.append(parts)
        print(f"Validated {level}: {len(ids)} states, {parts} parts, {vertices} vertices")
        assert not ids & countries, "state ids must not collide with country ids"
        for feature in load_regions("states", level)["features"]:
            parents.add(feature["properties"]["parent"])
        if level == "medium":
            collection = load_regions("states", level)
            for latitude, longitude in [(-33.8, 151.2), (-37.8, 145.0), (-31.9, 115.9), (-27.5, 153.0)]:
                print(f"  Coverage at {latitude}, {longitude}: {coverage_names(collection, latitude, longitude)}")
    assert identities[0] == identities[1] and part_counts[0] == part_counts[1]
    assert parents == set(metadata["parents"].values())


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--validate-only", action="store_true")
    arguments = parser.parse_args()
    if not arguments.validate_only:
        prepare()
    validate()
