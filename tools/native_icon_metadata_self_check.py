#!/usr/bin/env python3
"""Check the native equipment metadata schema and preserve the user's IRIS preset."""
import hashlib
import json
from pathlib import Path
from icon_studio.tag_all_icons import ANGLES, annotate_one
from icon_studio.validate_all_icons import catalog_entries

ROOT = Path(__file__).resolve().parents[1]
items = catalog_entries()
assert len(items) == 19
assert set(ANGLES) == {"head", "torso", "arms", "legs", "booster", "weapon_r", "weapon_l"}
native = (ROOT / "tools/icon_studio/sera_all_native_capture.gd").read_text(encoding="utf-8")
for slot, angle in ANGLES.items():
    assert f'"{slot}": Vector3({angle[0]}, {angle[1]}, {angle[2]})' in native, (
        slot, angle, "native capture and PNG metadata angles diverged")
assert "degrees = Vector3(-14, 48, 0)" in native
source = ROOT / items["H02"]["source_model"]
preset = json.loads((ROOT / "assets/ui/sera_icon_presets/H02.json").read_text(encoding="utf-8"))
assert hashlib.sha256(source.read_bytes()).hexdigest() == preset["source"]["fingerprint"]
assert items["H02"]["rig_set"] == "D"
script = (ROOT / "tools/icon_studio/tag_all_icons.py").read_text(encoding="utf-8")
for token in ('SERA_ICON_MANIFEST_V1', 'SERA_ICON_PNG_V1',
              'zlib.crc32(', 'read_png_metadata(path)',
              'png[:ihdr_end] + _chunk(b"tEXt", payload) + png[ihdr_end:]'):
    assert token in script, token
ci = (ROOT / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert "py tools/native_icon_metadata_self_check.py" in ci
print("SERA_NATIVE_ALL_PART_ICON_METADATA_STATIC_PASS")
