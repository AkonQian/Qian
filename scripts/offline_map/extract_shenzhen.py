#!/usr/bin/env python3
"""Extract real Shenzhen roads/buildings from a Geofabrik Guangdong PBF.

Dependencies: osmium, shapely. No public map tile scraping or invented geometry.
The existing JS writer performs WGS84 -> GCJ-02 and creates indexed SQLite v1.
"""
import argparse
import hashlib
import json
from pathlib import Path
import osmium
from shapely import from_wkb, make_valid
from shapely.geometry import mapping
from shapely.prepared import prep

RELATION = 3464353
HIGHWAYS = set("motorway motorway_link trunk trunk_link primary primary_link secondary secondary_link tertiary tertiary_link unclassified residential living_street service".split())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    factory = osmium.geom.WKBFactory()

    class Boundary(osmium.SimpleHandler):
        shape = None
        tags = None
        def relation(self, relation):
            if relation.id == RELATION:
                self.tags = dict(relation.tags)
        def area(self, area):
            if not area.from_way() and area.orig_id() == RELATION:
                self.shape = make_valid(from_wkb(factory.create_multipolygon(area)))

    boundary = Boundary()
    print("Reading Shenzhen municipal relation and assembling boundary...", flush=True)
    boundary.apply_file(str(args.source), locations=True, idx="flex_mem")
    if boundary.shape is None or boundary.shape.is_empty:
        raise RuntimeError("Complete Shenzhen boundary relation was not found")
    tags = boundary.tags or {}
    if tags.get("boundary") != "administrative" or "深圳" not in (tags.get("name", "") + tags.get("name:zh", "")):
        raise RuntimeError(f"Unexpected relation tags: {tags}")
    (args.output / "shenzhen-boundary.geojson").write_text(json.dumps({
        "type": "Feature", "properties": {"osm_relation": RELATION, **tags},
        "geometry": mapping(boundary.shape),
    }, ensure_ascii=False), encoding="utf-8")
    prepared = prep(boundary.shape)
    output_path = args.output / "shenzhen-roads-buildings.geojsonseq"
    stats = {"roads": 0, "buildings": 0, "geometry_errors": 0}

    def parts(shape, types):
        if shape.is_empty:
            return
        if shape.geom_type in types:
            yield shape
        elif hasattr(shape, "geoms"):
            for child in shape.geoms:
                yield from parts(child, types)

    with output_path.open("w", encoding="utf-8", newline="\n") as output:
        class Features(osmium.SimpleHandler):
            def emit(self, geometry, properties, feature_id, kind):
                if not prepared.intersects(geometry):
                    return
                clipped = geometry if prepared.covers(geometry) else geometry.intersection(boundary.shape)
                for index, shape in enumerate(parts(clipped, {"LineString"} if kind == "roads" else {"Polygon"})):
                    output.write(json.dumps({"type": "Feature", "id": f"{feature_id}/{index}",
                                             "properties": properties, "geometry": mapping(shape)},
                                            ensure_ascii=False, separators=(",", ":")) + "\n")
                    stats[kind] += 1
            def way(self, way):
                if way.tags.get("highway") not in HIGHWAYS:
                    return
                try:
                    self.emit(from_wkb(factory.create_linestring(way)), dict(way.tags), f"w{way.id}", "roads")
                except (osmium.InvalidLocationError, RuntimeError, ValueError):
                    stats["geometry_errors"] += 1
            def area(self, area):
                if "building" not in area.tags or area.tags.get("building") == "no":
                    return
                try:
                    geometry = make_valid(from_wkb(factory.create_multipolygon(area)))
                    self.emit(geometry, dict(area.tags), f"{'w' if area.from_way() else 'r'}{area.orig_id()}", "buildings")
                except (osmium.InvalidLocationError, RuntimeError, ValueError):
                    stats["geometry_errors"] += 1
        print("Clipping motor roads and building polygons to Shenzhen...", flush=True)
        Features().apply_file(str(args.source), locations=True, idx="flex_mem")
    reader = osmium.io.Reader(str(args.source), osmium.osm.NOTHING)
    timestamp = reader.header().get("osmosis_replication_timestamp")
    reader.close()
    checksum = hashlib.sha256()
    with args.source.open("rb") as source:
        for chunk in iter(lambda: source.read(4 * 1024 * 1024), b""):
            checksum.update(chunk)
    metadata = {
        "region": "深圳市", "boundary_relation": str(RELATION),
        "boundary_tags": tags, "bounds_wgs84": list(boundary.shape.bounds),
        "reference_latitude_deg": 22.6,
        "source_name": "OpenStreetMap / Geofabrik Guangdong extract",
        "source_url": "https://download.geofabrik.de/asia/china/guangdong.html",
        "source_download": "https://download.geofabrik.de/asia/china/guangdong-261103.osm.pbf",
        "source_timestamp": timestamp or "not present in PBF header", "source_sha256": checksum.hexdigest(),
        "extraction": "Exact municipal polygon intersection, WGS84; multipart geometry retained",
        "stats": stats,
    }
    (args.output / "source-metadata.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: metadata[key] for key in
                      ["region", "bounds_wgs84", "source_timestamp", "source_sha256", "stats"]},
                     ensure_ascii=True, indent=2), flush=True)


if __name__ == "__main__":
    main()
