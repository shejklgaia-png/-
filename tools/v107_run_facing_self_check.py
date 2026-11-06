#!/usr/bin/env python3
"""v107: verify the 90-degree Waist root-motion correction for authored RUN clips."""
import json
import math
from pathlib import Path

root = Path(__file__).resolve().parents[1]
rig = (root / "scripts/sera_rig.gd").read_text(encoding="utf-8")
model = json.loads((root / "assets/sera_source.json").read_text(encoding="utf-8"))
clips = {clip["name"]: clip for clip in model["animations"]}
waist = next(bone for bone in model["groups"] if bone["name"] == "Waist")
uid = waist["uuid"]
assert len(model["animations"]) == 17
assert uid == "67435cb7-b6af-23e4-10f1-3cd13d8429fa"
assert f'RUN_ROOT_BONE_UUID: String = "{uid}"' in rig
assert "RUN_ROOT_YAW_OFFSET_RADIANS: float = -PI * 0.5" in rig
assert "if uid == RUN_ROOT_BONE_UUID:" in rig
assert "sample_rotation = run_yaw_correction * sample_rotation" in rig
assert "sample_translation = run_yaw_correction * sample_translation" in rig
assert "var pose: Dictionary = _blended_run_pose(str(uid), t)" in rig

def corrected_facing(clip_name):
    # Blockbench ZYX rotation; Godot applies a world-space -90-degree yaw first.
    # Sample the initial Waist key to verify intended locomotion directions.
    frames = [k for k in clips[clip_name]["animators"][uid]["keyframes"]
              if k["channel"] == "rotation" and k["time"] == 0]
    assert len(frames) == 1, f"{clip_name} has no initial root rotation"
    p = frames[0]["data_points"][0]
    x, y, z = [math.radians(float(p[axis])) for axis in ("x", "y", "z")]
    # v = Rz(z)*Ry(y)*Rx(x)*Vector3(0,0,-1)
    vx = -math.cos(z)*math.sin(y)*math.cos(x)-math.sin(z)*math.sin(x)
    vz = -math.cos(y)*math.cos(x)
    # Ry(-90°) maps (vx,vz) to (-vz,vx)
    cx, cz = -vz, vx
    length = math.hypot(cx, cz)
    return cx / length, cz / length

for clip, expected in (
    ("run_front_original", "front"),
    ("run_back", "front"), # Backpedaling while still facing the target.
    ("run_right", "right"),
    ("run_Left", "left"),
):
    x, z = corrected_facing(clip)
    if expected == "front":
        assert z < -0.8, (clip, x, z)
    elif expected == "right":
        assert x > 0.8, (clip, x, z)
    else:
        assert x < -0.8, (clip, x, z)

main = (root / "scripts/main.gd").read_text(encoding="utf-8")
assert 'rig.call("set_moving", running, movement_boost_active, local_run_direction)' in main
assert "JUMP_TOUCH_INPUT_ENABLED: bool = false" in main
assert "const STRIKE_DAMAGE = [12, 12, 26]" in main
print("v107 Waist rotation & four-way RUN facing: PASS")
