#!/usr/bin/env python3
"""v293: authored Katana2 bones and 40%-closer camera without losing safety."""
import json
import math
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
project = (root / "project.godot").read_text(encoding="utf-8")
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
rig = (root / "scripts/sera_rig.gd").read_text(encoding="utf-8")
source = json.loads((root / "assets/sera_source.json").read_text(encoding="utf-8"))
author = json.loads((root / "models/storage/SERA_BOOSTER_allテスト.bbmodel").read_text(encoding="utf-8"))
assert re.search(r'config/name="SERA v(\d+)"', project)
assert int(re.search(r'config/name="SERA v(\d+)"', project).group(1)) >= 293
clip = next(c for c in author["animations"] if c["name"] == "Melee_katana2")
assert clip["loop"] == "once"
assert math.isclose(clip["length"], 0.58333, abs_tol=0.00001)
existing_uuids = {g["uuid"] for g in source["groups"]}
keyed = {uid: a["keyframes"] for uid, a in clip["animators"].items() if a.get("keyframes")}
assert len(keyed) == 19
assert sum(len(keys) for keys in keyed.values()) == 70
assert set(keyed).issubset(existing_uuids)
assert "Melee_katana2" not in [a["name"] for a in source["animations"]]
assert 'KATANA_SECOND_AUTHORING_SOURCE: String = "res://models/storage/SERA_BOOSTER_allテスト.bbmodel"' in rig
ready = rig.split("func _ready() -> void:",1)[1].split("func ",1)[0]
assert ready.index("_build_animations(data)") < ready.index("_merge_authored_katana_second_clip()") < ready.index("_build_katana_second_strike()")
importer = rig.split("func _merge_authored_katana_second_clip() -> void:",1)[1].split("func _build_katana_second_strike()",1)[0]
for token in ("if not FileAccess.file_exists(KATANA_SECOND_AUTHORING_SOURCE)", "bones.has(str(raw_uid))", '_build_animations({"animations": [authored]})'):
    assert token in importer, token
assert "if animations.has(KATANA_SECOND_CLIP) or not animations.has(KATANA_CLIP):" in rig
assert 'KATANA_SECOND_STRIKE_CLIP: String = "Melee_katana2"' in main
assert "return 2 if _katana_equipped() else STRIKE_CLIPS.size()" in main
assert "const CAMERA_DISTANCE_SCALE: float = 0.60" in main
assert "var camera_radius: float = CAMERA_BASE_RADIUS * CAMERA_DISTANCE_SCALE" in main
assert "var camera_follow_radius: float = CAMERA_BASE_RADIUS * CAMERA_DISTANCE_SCALE" in main
assert "    camera_radius = CAMERA_BASE_RADIUS * CAMERA_DISTANCE_SCALE" in main
assert "    camera_follow_radius = CAMERA_BASE_RADIUS * CAMERA_DISTANCE_SCALE" in main
assert "preferred_radius *= CAMERA_DISTANCE_SCALE" in main
assert "CAMERA_COMBAT_MIN_RADIUS * CAMERA_DISTANCE_SCALE" in main
assert math.isclose(16.0 * 0.60, 9.6)
assert math.isclose(8.8 * 0.60, 5.28)
assert math.isclose(11.3 * 0.60, 6.78)
for keep in ("_fit_full_frame()", "_minimum_boost_camera_radius()", "_fit_boost_frame_analytically(delta)", "_relax_camera_fit_radius(delta)", "camera_radius = maxf(camera_follow_radius, camera_fit_radius_floor)", "CAMERA_ELEVATION_RATIO * camera_radius"):
    assert keep in main, keep
print("V293_AUTHORED_KATANA2_CLOSE_CAMERA_STATIC_PASS")
