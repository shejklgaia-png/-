#!/usr/bin/env python3
"""v114: four authored BOOST poses, runtime blend wiring and model preservation."""
from pathlib import Path
import base64
import json
import math
import re

root = Path(__file__).resolve().parents[1]
def read(path):
    return (root / path).read_text(encoding="utf-8")

source_bytes = (root / "assets/sera_source.json").read_bytes()
source = json.loads(source_bytes)
user = json.loads(read("models/SERA_BOOSTER_all.bbmodel"))
original_v106 = json.loads(read("blockbench/SERA_v106_four_way_run_integrated.bbmodel"))
clips = {a["name"]: a for a in source["animations"]}
authored = {a["name"]: a for a in user["animations"]}
names = ("Boost_front", "Boost_back", "Boost_Left", "Boost_right")
assert len(source["animations"]) == len(clips) == 20
assert len(source["groups"]) == 22 and len(source["elements"]) == 25
for key in ("elements", "groups", "outliner", "textures"):
    assert source[key] == original_v106[key], key
for name in names:
    assert clips[name] == authored[name], name
    assert clips[name]["loop"] == "loop" and clips[name]["length"] == 0, name
    frames = [k for a in clips[name]["animators"].values()
              for k in a.get("keyframes", [])]
    assert len(frames) == 21 and all(float(k["time"]) == 0 for k in frames), name
    assert set(clips[name]["animators"]).issubset(
        {g["uuid"] for g in source["groups"]}), name
for name in ("run_front_original", "run_back", "run_right", "run_Left",
             "Jump", "Guard", "melee1", "Melee2", "Melee3", "Backstep",
             "Step_R", "Step_L", "Wait_motion", "meleeboost"):
    assert name in clips, name
assert (root / "blockbench/SERA_v114_boost_four_way_integrated.bbmodel").read_bytes() == source_bytes
parts = re.findall(r'^    "([A-Za-z0-9+/=]+)",$', read("assets/sera_data.gd"), re.M)
assert base64.b64decode("".join(parts), validate=True) == source_bytes
rig = read("scripts/sera_rig.gd")
main = read("scripts/main.gd")
project = read("project.godot")
for token in (
    'const BOOST_CLIP: String = "Boost_front"',
    'const BOOST_BACK_CLIP: String = "Boost_back"',
    'const BOOST_RIGHT_CLIP: String = "Boost_right"',
    'const BOOST_LEFT_CLIP: String = "Boost_Left"',
    'const BOOST_DIRECTION_BLEND_SECONDS: float = 0.045',
    'func _set_boost_motion_direction(local_direction: Vector2) -> void:',
    'func _blended_boost_pose(uid: String) -> Dictionary:',
    'func _sample_boost_pose(clip_name: String, uid: String) -> Dictionary:',
    'fore_aft_rotation.slerp(lateral_rotation, lateral_weight).normalized()',
    'var angle_delta: float = wrapf(angle_goal - angle_now, -PI, PI)',
    'boost_direction_smoothed = boost_update["heading"]',
    'var boost_pose: Dictionary = _blended_boost_pose(str(uid))',
    'func _blended_run_pose(uid: String, t: float, stabilize_head: bool = true)',
    'const RUN_HEAD_SWAY_RETENTION: float = 0.35',
):
    assert token in rig, token
assert rig.count('var boost_pose: Dictionary = _blended_boost_pose(str(uid))') == 1
assert 'rig.call("set_moving", running, movement_boost_active, local_run_direction)' in main
assert 'state_label.text = "BOOST  x1.5  |  %s" % str(rig.call("get_boost_dominant_clip"))' in main
assert 'const MOVEMENT_BOOST_MULTIPLIER: float = 1.5' in main
assert 'const STRIKE_DAMAGE = [12, 12, 26]' in main
assert 'config/name="SERA v' in project
for x,y in ((0,1),(1,0),(-1,0),(0,-1),(1,1),(-1,1),(-1,-1),(1,-1)):
    weight=math.atan2(abs(x),abs(y))/(math.pi/2)
    assert 0 <= weight <= 1
    if x==0: assert weight==0
    if y==0: assert weight==1
print("v114 BOOST 4-way authored assets / quaternion blend / regression: PASS")
