#!/usr/bin/env node
import fs from "node:fs";
import crypto from "node:crypto";
import { DatabaseSync } from "node:sqlite";

const filename = process.argv[2] ?? "shared/offline_map/shenzhen-v1.sqlite";
const db = new DatabaseSync(filename, { readOnly: true });
const check = (valid, reason) => { if (!valid) throw new Error(reason); };
const metadata = Object.fromEntries(db.prepare("SELECT key,value FROM metadata").all().map(x => [x.key, x.value]));
check(metadata.region === "深圳市" && metadata.region_osm_relation === "3464353", "Wrong city/source relation");
check(metadata.schema_version === "1" && metadata.coordinate_system === "GCJ-02", "Wrong schema/coordinate system");
check(metadata.attribution.includes("OpenStreetMap"), "Missing attribution");
check(db.prepare("PRAGMA user_version").get().user_version === 1, "Wrong schema version");
check(db.prepare("PRAGMA application_id").get().application_id === 0x4d475053, "Wrong application ID");
check(db.prepare("PRAGMA integrity_check").get().integrity_check === "ok", "SQLite integrity failed");
const counts = {};
for (const table of ["roads", "buildings"]) {
  const index = table === "roads" ? "road_rtree" : "building_rtree";
  const rows = db.prepare(`SELECT * FROM ${table}`).iterate();
  let count = 0, pointCount = 0;
  for (const row of rows) {
    count++;
    check(row.osm_way_id != null, "Feature without source ID");
    check(row.class >= 0 && row.class <= (table === "roads" ? 5 : 2), "Unknown feature class");
    check(row.points.length % 8 === 0 && row.points.length >= (table === "roads" ? 16 : 24), "Invalid point blob");
    const bytes = Buffer.from(row.points); let minLat=Infinity,maxLat=-Infinity,minLng=Infinity,maxLng=-Infinity;
    for (let i=0;i<bytes.length;i+=8) {
      const lat=bytes.readInt32LE(i),lng=bytes.readInt32LE(i+4);pointCount++;
      check(lat >= 22_000_000 && lat <= 24_000_000 && lng >= 113_000_000 && lng <= 116_000_000, "Geometry outside Shenzhen vicinity");
      minLat=Math.min(minLat,lat);maxLat=Math.max(maxLat,lat);minLng=Math.min(minLng,lng);maxLng=Math.max(maxLng,lng);
    }
    check(minLat===row.min_lat_e6 && maxLat===row.max_lat_e6 && minLng===row.min_lon_e6 && maxLng===row.max_lon_e6,"Geometry bounds mismatch");
    if (table === "buildings") check(!bytes.subarray(0,8).equals(bytes.subarray(-8)),"Repeated polygon closure");
  }
  check(count > 1000, `Unexpectedly sparse ${table}`);
  check(count === db.prepare(`SELECT count(*) n FROM ${index}`).get().n, "R-tree count mismatch");
  const mismatch=db.prepare(`SELECT count(*) n FROM ${table} f LEFT JOIN ${index} i ON f.id=i.id WHERE i.id IS NULL OR f.min_lat_e6!=i.min_lat_e6 OR f.max_lat_e6!=i.max_lat_e6 OR f.min_lon_e6!=i.min_lon_e6 OR f.max_lon_e6!=i.max_lon_e6`).get().n;
  check(mismatch===0,"R-tree geometry mismatch");
  counts[table]={features:count,points:pointCount};
}
const probe = (lat,lng) => Object.fromEntries(["road_rtree","building_rtree"].map(table => [table, db.prepare(`SELECT count(*) n FROM ${table} WHERE max_lat_e6>=? AND min_lat_e6<=? AND max_lon_e6>=? AND min_lon_e6<=?`).get(Math.round((lat-.0045)*1e6),Math.round((lat+.0045)*1e6),Math.round((lng-.0049)*1e6),Math.round((lng+.0049)*1e6)).n]));
const probes = {
  shenzhenCenter:probe(22.545,114.065), nanshan:probe(22.54,113.943), luohu:probe(22.548,114.115),
  baoan:probe(22.568,113.88), longgang:probe(22.72,114.25), dapeng:probe(22.60,114.47),
  excludedJinan:probe(36.675,117.128)
};
check(probes.shenzhenCenter.road_rtree>0 && probes.shenzhenCenter.building_rtree>0,"No map geometry in Shenzhen center");
check(probes.excludedJinan.road_rtree===0 && probes.excludedJinan.building_rtree===0,"Jinan data leaked into Shenzhen pack");
db.close();
console.log(JSON.stringify({database:filename,bytes:fs.statSync(filename).size,sha256:crypto.createHash("sha256").update(fs.readFileSync(filename)).digest("hex"),metadata,counts,probes,integrity:"ok"},null,2));
