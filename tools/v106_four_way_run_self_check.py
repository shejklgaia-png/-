#!/usr/bin/env python3
"""v106 4-way run animation data / legacy preservation / wiring check."""
from pathlib import Path
import json, base64, re

root = Path(__file__).resolve().parents[1]
def text(path):
    return (root / path).read_text(encoding="utf-8")
source_bytes = (root / "assets/sera_source.json").read_bytes()
source = json.loads(source_bytes)
user = json.loads(text("bbmodel/SERA_back.bbmodel"))
legacy = json.loads(text("blockbench/SERA_v102_guardfix_integrated.bbmodel"))
merged = json.loads(text("blockbench/SERA_v106_four_way_run_integrated.bbmodel"))
assert len(merged["animations"]) == 17, "Historical v106 model must stay unchanged"
for key in ("elements", "groups", "outliner", "textures"):
    assert source[key] == legacy[key], f"Unexpected change to {key}"
clips = {a["name"]: a for a in source["animations"]}
user_clips = {a["name"]: a for a in user["animations"]}
old_clips = {a["name"]: a for a in legacy["animations"]}
names = ("run_front_original", "run_back", "run_right", "run_Left")
assert len(clips) == len(old_clips) + 6 == 20
bones = {g["uuid"] for g in source["groups"]}
for name in names:
    clip = clips[name]
    assert clip == user_clips[name], f"User-authored clip differs: {name}"
    assert clip["loop"] == "loop" and clip["length"] == 1.0
    assert sum(len(a.get("keyframes", [])) for a in clip["animators"].values()) > 0
    for uid, animator in clip["animators"].items():
        assert uid in bones or uid == "effects", f"Unknown animator bone: {uid}"
        for k in animator.get("keyframes", []):
            assert 0 <= k["time"] <= 1.0
for name in old_clips.keys() - {"run_front_original"}:
    assert clips[name] == old_clips[name], f"Preexisting animation altered: {name}"
embedded = text("assets/sera_data.gd")
parts = re.findall(r'^\s+"([A-Za-z0-9+/=]+)",?$', embedded, re.M)
assert base64.b64decode("".join(parts), validate=True) == source_bytes
rig = text("scripts/sera_rig.gd")
main = text("scripts/main.gd")
for name in names:
    assert f'"{name}"' in rig
assert "current_clip in RUN_CLIPS" in rig
assert "delta * (RUN_ANIMATION_SPEED if current_clip in RUN_CLIPS else 1.0)" in rig
assert "world_move.dot(target_forward.cross(Vector3.UP))" in main
assert "world_move.dot(target_forward)" in main
assert 'rig.call("set_moving", running, movement_boost_active, local_run_direction)' in main
assert "JUMP_TOUCH_INPUT_ENABLED: bool = false" in main
assert "const STRIKE_DAMAGE = [12, 12, 26]" in main
print("v106 4-direction RUN / embedded source / previous asset preservation: PASS")
