#!/usr/bin/env python3
"""v311: active lock target defines STEP forward; travel remains screen-based."""
import base64, json, re
from pathlib import Path

# v317 relocated pure math: validate the actual new code and main.gd facade.
from pathlib import Path as _SplitPath
SERA_INPUT = (_SplitPath(__file__).resolve().parents[1] / "scripts/sera_input_gestures.gd").read_text(encoding="utf-8")
SERA_MOVEMENT = (_SplitPath(__file__).resolve().parents[1] / "scripts/sera_movement_math.gd").read_text(encoding="utf-8")

R = Path(__file__).resolve().parents[1]
def read(path): return (R/path).read_text(encoding="utf-8")
main=read("scripts/main.gd")
rig=read("scripts/sera_rig.gd")
version=int(re.search(r'config/name="SERA v(\d+)"',read("project.godot")).group(1))
assert version >= 311
helper=main.split("func _step_motion_direction(world_direction: Vector3,",1)[1].split(
    "# Kick sectors are fixed SCREEN",1)[0]
assert "target_hp > 0" in helper
for marker in ("auto_lock_enabled","manual_part_lock_active","auto_lock_initialized",
               "locked_target_part_id.is_empty()"):
    assert marker in helper,marker
assert "return _step_local_pose_direction(world_direction)" in helper
assert "return screen_direction.normalized()" in helper
local=main.split("func _step_local_pose_direction(world_direction: Vector3) -> Vector2:",1)[1].split(
    "func _step_motion_direction(",1)[0]
assert "_locked_target_facing_direction()" in local
assert "-player.global_transform.basis.z" in local
assert "facing = player_forward" in SERA_MOVEMENT
assert "MOVEMENT_MATH.step_local_pose_direction(" in local
assert "world_unit.dot(right), -world_unit.dot(facing)" in SERA_MOVEMENT
start=main.split("func _start_omni_step(flick: Vector2) -> bool:",1)[1].split(
    "func _start_back_step()",1)[0]
for marker in ('var direction: Vector2 = flick.normalized()',
               'var world_step: Vector3 = _screen_drag_to_ground(direction)',
               'var pose_direction: Vector2 = _step_motion_direction(world_step, direction)',
               'step_linear_offset = Vector2(world_step.x, world_step.z)',
               'step_arc_length = _step_fixed_distance_for_direction(direction)',
               'rig.call("start_omni_step", pose_direction)'):
    assert marker in start,marker
physics=main.split("func _physics_process(delta: float) -> void:",1)[1].split(
    "func _process(delta: float) -> void:",1)[0]
assert 'var committed_world_step: Vector3 = Vector3(' in physics
assert 'rig.call("update_omni_step_direction", _step_motion_direction(' in physics
assert 'committed_world_step, step_flick_this_frame), delta)' in physics
assert 'committed_world_step, step_flick_this_frame), delta)' in physics
assert 'rig.call("update_omni_step_direction", step_flick_this_frame, delta)' not in physics
assert "facing_weight *= 1.0 - _step_right_authored_yaw_weight()" in rig
assert "directional_step_vector.slerp(" in rig
original=json.loads(read("models/storage/SERA_BOOSTER_allテスト (9) (2) (2).bbmodel"))
current=json.loads(read("assets/sera_source.json"))
clip=lambda d: next(x for x in d["animations"] if x["name"]=="Step_R")
assert clip(original)==clip(current),"9.2.2 authored Step_R modified"
parts=re.findall(r'^    "([A-Za-z0-9+/=]+)",$',read("assets/sera_data.gd"),re.M)
assert base64.b64decode("".join(parts))==(R/"assets/sera_source.json").read_bytes()
print("PASS v311: selected-part forward for STEP pose, screen-linear travel and original 9.2.2 clip")
