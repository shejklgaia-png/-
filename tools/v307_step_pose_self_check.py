#!/usr/bin/env python3
"""v307 STEP pose mappings use current lock facing, not a one-frame-old model yaw."""
from pathlib import Path
import json,re
root=Path(__file__).resolve().parents[1]
m=(root/"scripts/main.gd").read_text(encoding="utf-8")
r=(root/"scripts/sera_rig.gd").read_text(encoding="utf-8")
p=(root/"project.godot").read_text(encoding="utf-8")
model=json.loads((root/"assets/sera_source.json").read_text(encoding="utf-8"))
assert int(re.search(r'^config/name="SERA v(\d+)"$',p,re.M).group(1)) >= 307
section=m.split("func _step_local_pose_direction(world_direction: Vector3) -> Vector2:",1)[1].split("func _request_combo_side_kick(",1)[0]
assert "var facing: Vector3 = _locked_target_facing_direction()" in section
assert "if facing.length_squared() < 0.000001:" in section
assert "facing = -player.global_transform.basis.z" in section
assert "facing.cross(Vector3.UP)" in section
assert "return Vector2(world_unit.dot(right), -world_unit.dot(facing)).normalized()" in section
for clip_name in ("Step_R","Step_L","Frontstep","Backstep"):
    src=next(x for x in model["animations"] if x["name"]==clip_name)
    assert len([x for x in src["animators"].values() if x.get("keyframes")])>=12,clip_name
assert 'rig.call("start_omni_step", pose_direction)' in m
assert 'rig.call("update_omni_step_direction",' in m
assert "step_linear_offset = Vector2(world_step.x, world_step.z)" in m
assert "STEP_RIGHT_CLIP if direction.x >= 0.0 else STEP_LEFT_CLIP" in r
assert "var fore_aft: Dictionary = _sample_step_clip_pose(STEP_FORWARD_CLIP, uid, 0.0)" in r
print("V307_STEP_POSE_SOURCE_AND_LOCK_STATIC_PASS")
