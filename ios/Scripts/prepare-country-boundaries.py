import argparse
import json
import tempfile

from region_pipeline import (
    LEVELS, OUTPUT, REVISION, coverage_names, download, load_regions, regroup,
    simplify, validate_file, write_level,
)

SOURCE = f"https://raw.githubusercontent.com/nvkelso/natural-earth-vector/{REVISION}/50m_cultural/ne_50m_admin_0_countries"


def prepare():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    metadata = {
        "source": "Natural Earth Admin 0 Countries, 1:50 million",
        "version": "5.1.1",
        "revision": REVISION,
        "url": "https://www.naturalearthdata.com/downloads/50m-cultural-vectors/50m-admin-0-countries-2/",
        "license": "Public domain",
        "licenseURL": "https://www.naturalearthdata.com/about/terms-of-use/",
        "tool": "mapshaper@0.7.101",
        "simplification": "spherical weighted Visvalingam; exploded parts with keep-shapes; shared topology",
        "precisionDegrees": 0.00001,
        "levels": {},
    }
    with tempfile.TemporaryDirectory() as temporary:
        from pathlib import Path
        directory = Path(temporary)
        download(directory, SOURCE, "countries")
        for level, interval in LEVELS.items():
            target = directory / f"{level}.geojson"
            simplify(
                directory, "countries",
                'id=String(NE_ID),name=NAME_EN,kind="country"',
                "id,name,kind", interval, target,
            )
            collection = json.loads(target.read_text())
            regroup(collection)
            metadata["levels"][level] = write_level(collection, "countries", level, interval, "countries")
            print(level, metadata["levels"][level])
    (OUTPUT / "countries-source.json").write_text(json.dumps(metadata, indent=2) + "\n")


def validate():
    metadata = json.loads((OUTPUT / "countries-source.json").read_text())
    identities = []
    part_counts = []
    for level in LEVELS:
        ids, parts, vertices = validate_file("countries", level, metadata["levels"][level], "countries")
        identities.append(ids)
        part_counts.append(parts)
        print(f"Validated {level}: {len(ids)} countries, {parts} parts, {vertices} vertices")
        if level == "medium":
            collection = load_regions("countries", level)
            for latitude, longitude in [(-25, 134), (48.85, 2.35), (46.8, 8.2), (-17.8, 178), (-16.8, -179.9), (0, -140)]:
                print(f"  Coverage at {latitude}, {longitude}: {coverage_names(collection, latitude, longitude)}")
    assert identities[0] == identities[1] and part_counts[0] == part_counts[1]


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--validate-only", action="store_true")
    arguments = parser.parse_args()
    if not arguments.validate_only:
        prepare()
    validate()
