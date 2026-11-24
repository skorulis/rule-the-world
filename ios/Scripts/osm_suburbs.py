"""Suburb/locality boundary extraction from OpenStreetMap.

Downloads a Geofabrik `.osm.pbf` extract and assembles administrative
boundary relations (``boundary=administrative``) into GeoJSON polygons using
libosmium's area assembler. Australian suburbs and localities are
``admin_level=9`` (with a small number of ``admin_level=10`` enclaves);
``admin_level=4`` state borders are collected as well so each suburb's
``parent`` can be assigned to the Natural Earth state id used by
``states-medium.pbf``.

See README-region-data.md for the full ingestion workflow.
"""
from __future__ import annotations

import urllib.request
from pathlib import Path

import osmium
from shapely.geometry import MultiPolygon, Polygon

GEOFABRIK_URL = "https://download.geofabrik.de/australia-oceania/australia/australia-261123.osm.pbf"
STATE_ADMIN_LEVEL = "4"
SUBURB_ADMIN_LEVELS = {"9", "10"}
OSM_ID_BASE = 9_200_000_000_000  # reserved suburb id range for OSM relation ids

# ISO 3166-2 code -> Natural Earth state name as stored in states-medium.pbf.
# New South Wales is deliberately absent: its suburbs come from the NSW
# FeatureServer so existing ids stay stable. Add entries here to ingest
# additional first-level regions from OpenStreetMap.
STATES = {
    "AU-VIC": "Victoria",
    "AU-QLD": "Queensland",
    "AU-SA": "South Australia",
    "AU-WA": "Western Australia",
    "AU-TAS": "Tasmania",
    "AU-NT": "Northern Territory",
    "AU-ACT": "Australian Capital Territory",
    "AU-JBT": "Jervis Bay Territory",
}

# States that must produce at least one suburb for the dataset to be valid.
# Small territories (e.g. Jervis Bay) may have no admin_level=9/10 relations.
REQUIRED_STATES = {"AU-VIC", "AU-QLD", "AU-SA", "AU-WA", "AU-TAS", "AU-NT", "AU-ACT"}


def download(url: str, target: Path):
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        return
    with urllib.request.urlopen(url) as response:
        target.write_bytes(response.read())


class _BoundaryAreas(osmium.SimpleHandler):
    """Collect assembled areas for boundary=administrative relations."""

    def __init__(self):
        super().__init__()
        self.states = []   # (name, shapely geometry)
        self.suburbs = []  # (relation_id, name, admin_level, shapely geometry)

    def area(self, area):
        if area.from_way():
            return
        tags = {tag.k: tag.v for tag in area.tags}
        level = tags.get("admin_level")
        name = tags.get("name")
        if level not in SUBURB_ADMIN_LEVELS | {STATE_ADMIN_LEVEL} or not name:
            return
        polygons = []
        for ring in area.outer_rings():
            polygon = Polygon(
                [(node.lon, node.lat) for node in ring],
                [[(node.lon, node.lat) for node in inner] for inner in area.inner_rings(ring)],
            )
            polygons.append(polygon)
        assert polygons, f"relation {area.orig_id()} produced no polygons"
        geometry = polygons[0] if len(polygons) == 1 else MultiPolygon(polygons)
        if level == STATE_ADMIN_LEVEL:
            self.states.append((name, geometry))
        else:
            self.suburbs.append((area.orig_id(), name, level, geometry))


def collect_suburbs(source: Path):
    """Assemble admin boundaries from an .osm.pbf extract.

    Returns (suburbs, states) where suburbs is a list of
    (relation_id, name, admin_level, shapely geometry) and states is a list of
    (name, shapely geometry) for admin_level=4 relations.
    """
    collector = _BoundaryAreas()
    collector.apply_file(
        str(source),
        idx="sparse_file_array",
        filters=[osmium.filter.TagFilter(("boundary", "administrative"))],
    )
    return collector.suburbs, collector.states


def _point(geometry):
    point = geometry.representative_point()
    assert geometry.contains(point) or geometry.touches(point), point
    return point


def normalize(suburbs, states, state_ids):
    """Convert assembled OSM areas into normalized GeoJSON features.

    ``state_ids`` maps Natural Earth state name -> id (from states-medium.pbf).
    The parent state is the admin_level=4 relation containing the suburb's
    representative point; suburbs outside every collected state are skipped
    (territories not covered by the Geofabrik Australia extract).
    """
    named = {name: geometry for name, geometry in states}
    assert "New South Wales" in named, "state borders missing from extract"
    features = []
    skipped = []
    seen = set()
    for relation_id, name, level, geometry in sorted(suburbs):
        assert relation_id not in seen, f"duplicate relation {relation_id}"
        seen.add(relation_id)
        point = _point(geometry)
        parent_name = next((name for name, border in named.items() if border.covers(point)), None)
        # NSW suburbs are intentionally skipped: the dataset sources them from
        # the NSW FeatureServer so existing ids stay stable (see README-region-data.md).
        # States absent from states-medium.pbf (external territories modelled
        # as separate Natural Earth countries) are skipped as well.
        if parent_name is None or parent_name == "New South Wales" or parent_name not in state_ids:
            skipped.append((relation_id, name))
            continue
        identity = str(OSM_ID_BASE + relation_id)
        features.append({
            "type": "Feature",
            "properties": {
                "id": identity,
                "name": name.strip(),
                "kind": "suburb",
                "parent": state_ids[parent_name],
            },
            "geometry": geometry.__geo_interface__,
        })
    features.sort(key=lambda feature: feature["properties"]["id"])
    return {"type": "FeatureCollection", "features": features}, skipped, {name for name, _ in states}
