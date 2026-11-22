from pathlib import Path
import sys
import tempfile
import unittest

import geobuf

from region_pipeline import ROOT, encode_collection, validate_file, write_level


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
