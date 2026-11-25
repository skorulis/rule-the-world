import json
from pathlib import Path
import sys
import tempfile
import unittest

import geobuf
import h3

from region_pipeline import ROOT, encode_collection, load_shards, validate_file, validate_shards, write_level, write_shards


def fixture():
    return {
        "type": "FeatureCollection",
        "features": [
            {
                "type": "Feature",
                "properties": {"id": "42", "name": "Île précise", "kind": "country"},
                "geometry": {
                    "type": "Polygon",
                    "coordinates": [[[1.000001, 1.000002], [5, 1.000002], [5, 5], [1.000001, 5], [1.000001, 1.000002]]],
                },
            },
            {
                "type": "Feature",
                "properties": {"id": "43", "name": "Islands", "kind": "state", "parent": "42"},
                "geometry": {
                    "type": "MultiPolygon",
                    "coordinates": [
                        [[[10, 0], [20, 0], [20, 10], [10, 10], [10, 0]], [[12, 2], [14, 2], [14, 4], [12, 4], [12, 2]]],
                        [[[30, 0], [32, 0], [32, 2], [30, 2], [30, 0]]],
                    ],
                },
            },
        ],
    }


class RegionPipelineTests(unittest.TestCase):
    def test_interoperability_fixture_matches_encoder_and_round_trips(self):
        encoded = encode_collection(fixture())
        self.assertEqual(geobuf.decode(encoded), fixture())
        self.assertEqual(encoded, (ROOT / "data/regions/geobuf-fixture.pbf").read_bytes())
        self.assertEqual(encoded, encode_collection(fixture()))

    def test_write_level_records_and_validates_binary_counts(self):
        collection = fixture()
        collection["features"][0]["geometry"] = {
            "type": "MultiPolygon", "coordinates": [collection["features"][0]["geometry"]["coordinates"]],
        }
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            stats = write_level(collection, "countries", "medium", 3000, "countries", output=output)
            ids, parts, vertices = validate_file("countries", "medium", stats, "countries", output=output)
            self.assertEqual((ids, parts, vertices), ({"42", "43"}, 3, 20))
            self.assertLess(stats["bytes"], stats["geojsonBytes"])
            self.assertFalse(list(output.glob("*.geojson")))
            data = output / "countries-medium.pbf"
            data.write_bytes(data.read_bytes()[:-1])
            with self.assertRaises(AssertionError):
                validate_file("countries", "medium", stats, "countries", output=output)

    def test_write_shards_indexes_covering_cells(self):
        collection = fixture()
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            write_shards(collection, "regions", output=output)
            index = json.loads((output / "regions-index.json").read_text())
            expected = {"regions": 2, "polygonParts": 3, "vertices": 20}
            ids, parts, vertices = validate_shards("regions", index, expected, "regions", output=output)
            self.assertEqual((ids, parts, vertices), ({"42", "43"}, 3, 20))
            self.assertEqual(load_shards("regions", output=output), collection)
            cell = h3.latlng_to_cell(5, 12, index["shardResolution"])
            self.assertIn("43", index["coverage"].get(cell, []))
            self.assertNotIn("42", index["coverage"].get(cell, []))
            home = index["homes"]["43"]
            shard = geobuf.decode((output / "regions" / f"{home}.pbf").read_bytes())
            self.assertIn("43", {feature["properties"]["id"] for feature in shard["features"]})

    def test_more_precise_coordinates_are_not_silently_quantized(self):
        collection = fixture()
        collection["features"][0]["geometry"]["coordinates"][0][0][0] = 1.0000001
        with self.assertRaises(AssertionError):
            encode_collection(collection)


if __name__ == "__main__":
    if sys.argv[1:] == ["--write-fixture"]:
        (ROOT / "data/regions/geobuf-fixture.pbf").write_bytes(encode_collection(fixture()))
    else:
        unittest.main()
