#!/usr/bin/env python3
"""v295 regression: RUN travel heading and clean recovery after any combat clip."""
from pathlib import Path
import math
import re

R = Path(__file__).resolve().parents[1]
rig = (R / "scripts/sera_rig.gd").read_text(encoding="utf-8")
main = (R / "scripts/main.gd").read_text(encoding="utf-8")
project = (R / "project.godot").read_text(encoding="utf-8")
assert int(re.search(r'config/name="SERA v(\d+)"', project).group(1)) >= 295
assert (R / "README_v295_ja.md").is_file()
assert "RUN_ROOT_YAW_OFFSET_RADIANS: float = -PI * 0.5" in rig
assert 'source_name: String = RUN_CLIP if i == 0 else RUN_BACK_CLIP' in rig
assert "_update_run_retreat_mode(heading)" in rig
assert "_run_joint_yaw_targets()" in rig
assert "run_direction_smoothed = run_update[\"heading\"]" in rig
assert "run_turn_lean_degrees = lerpf(" in rig
assert "run_facing_yaw + clampf(yaw_error, -yaw_step, yaw_step)" in rig

switch = rig.split("func _switch_clip(wanted: String, fade_seconds: float) -> void:", 1)[1].split(
    "func start_guard()", 1)[0]
for token in (
    "if wanted not in RUN_CLIPS:",
    "run_motion_initialized = false",
    "run_turn_previous_direction = Vector2.ZERO",
    "run_turn_lean_degrees = 0.0",
):
    assert token in switch, token

heading = rig.split(
    "func _run_yaw_for_direction(direction: Vector2, retreat_weight: float) -> float:", 1)[1].split(
    "func _smooth_visual_direction(", 1)[0]
assert "return travel_yaw" in heading
assert "RUN_TARGET_LOCK_MAX_YAW_DEGREES" not in rig
apply = rig.split("func _apply_animation(_delta: float) -> void:", 1)[1].split(
    "func _blockbench_rotation(", 1)[0]
assert "elif running_pose:" in apply
assert 'var pose: Dictionary = _blended_run_pose(str(uid), t)' in apply
lock = apply.split("if uid == RUN_ROOT_BONE_UUID and (", 1)[1].split(
    "bone.quaternion = q", 1)[0]
assert "current_clip == BOOST_CLIP" in lock
assert "(step_playback and directional_step_active)" in lock
assert "running_pose or" not in lock
assert "q = _face_locked_boss_with_waist(q, blend_weight)" in lock
assert "blended_rotation = (facing * blended_rotation).normalized()" in rig
assert "var gaze := Quaternion(Vector3.UP, run_upper_yaw_offsets[part_index])" in rig
assert 'rig.call("set_moving", show_moving_pose, show_boost_pose,' in main
assert "world_move.dot(target_forward.cross(Vector3.UP))" in main
assert "world_move.dot(target_forward)" in main
assert "player.look_at(player.global_position + aim, Vector3.UP)" in main
assert 'rig.call("finish_attack", false, jump_active and not damage_reaction_active)' in main

def yaw(x: float, y: float, retreat: float, side: float) -> float:
    theta = math.atan2(x, y)
    return (-theta + math.pi * retreat * side + math.pi) % (2 * math.pi) - math.pi

for x, y, retreat, side, wanted in [
    (0, 1, 0, 1, 0), (1, 0, 0, 1, -90),
    (-1, 0, 0, -1, 90), (0, -1, 1, 1, 0),
    (1, -1, 1, 1, 45), (-1, -1, 1, -1, -45),
]:
    got = math.degrees(yaw(x, y, retreat, side))
    assert abs(got - wanted) < 1e-6, (x, y, got, wanted)
print("V295_RUN_DIRECTION_MELEE_RECOVERY_STATIC_PASS")
