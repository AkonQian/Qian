#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"
SOURCE_DIR="tmp/offline_map_source/shenzhen"
mkdir -p "$SOURCE_DIR"
SOURCE="$SOURCE_DIR/guangdong-261103.osm.pbf"
if [[ ! -s "$SOURCE" ]]; then
  curl --fail --location --retry 3 \
    'https://download.geofabrik.de/asia/china/guangdong-261103.osm.pbf' -o "$SOURCE"
fi
python3 - "$SOURCE" <<'PY'
import hashlib, sys
from pathlib import Path
p = Path(sys.argv[1])
actual = hashlib.md5(p.read_bytes()).hexdigest()
if actual != '12b9b7acfbadd9da69e493f38830f3f8':
    raise SystemExit('Downloaded Guangdong snapshot checksum mismatch: ' + actual)
PY
python3 scripts/offline_map/extract_shenzhen.py "$SOURCE" "$SOURCE_DIR"
node scripts/offline_map/build_jinan_sqlite.mjs \
  "$SOURCE_DIR/shenzhen-roads-buildings.geojsonseq" \
  shared/offline_map/shenzhen-v1.sqlite "$SOURCE_DIR/source-metadata.json"
node scripts/offline_map/validate_shenzhen_sqlite.mjs
