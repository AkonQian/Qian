"""Restore the exact released database when Geofabrik retires its dated PBF."""
from pathlib import Path
import hashlib
import io
import sys
import zipfile

artifact = Path(sys.argv[1])
expected_artifact = '2d710a12cfec68742d75ebe55beccc21f407e2bc30a317fd3392b59639d9dacd'
expected_map = '665b8bc749b6dab1f3a3ee48f3b26b1e901d1850ad754edbe66c9258c46a2885'
assert hashlib.sha256(artifact.read_bytes()).hexdigest() == expected_artifact
with zipfile.ZipFile(artifact) as outer:
    ipa = next(n for n in outer.namelist() if n.endswith('MOTO-GPS-0.3.13-19-unsigned.ipa'))
    with zipfile.ZipFile(io.BytesIO(outer.read(ipa))) as inner:
        name = next(n for n in inner.namelist() if n.endswith('.app/shenzhen-v1.sqlite'))
        data = inner.read(name)
assert hashlib.sha256(data).hexdigest() == expected_map
target = Path(__file__).resolve().parents[2] / 'shared/offline_map/shenzhen-v1.sqlite'
target.write_bytes(data)
print(f'Restored released Shenzhen database: {len(data)} bytes, SHA256 {expected_map}')
