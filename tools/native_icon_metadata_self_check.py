#!/usr/bin/env python3
"""Check the native equipment metadata schema and preserve the user's IRIS preset."""
import hashlib
import json
from pathlib import Path
from icon_studio.tag_all_icons import ANGLES, OBLIQUE_POSE, annotate_one
from icon_studio.validate_all_icons import catalog_entries

ROOT = Path(__file__).resolve().parents[1]
items = catalog_entries()
assert len(items) == 19
assert set(ANGLES) == {"head", "torso", "arms", "legs", "booster", "weapon_r", "weapon_l"}
native = (ROOT / "tools/icon_studio/sera_all_native_capture.gd").read_text(encoding="utf-8")
assert OBLIQUE_POSE == (11.8749389648438, 156.900744628906, 0.0)
assert all(angle == OBLIQUE_POSE for angle in ANGLES.values())
assert 'const CAMERA_PRESET_PATH: String = "res://assets/ui/sera_icon_presets/H02.json"' in native
assert '2.0 * auto_fit * model_scale / span' in native
assert 'func _equalize_transparent_margins(' in native
assert 'const POSE_NAMES = ["NEXUS_pose", "NEXUSpose"]' in native
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
