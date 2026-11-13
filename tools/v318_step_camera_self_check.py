#!/usr/bin/env python3
"""v318: 4m STEP/0.3m swept warp and smooth camera response profiles."""
from pathlib import Path
import re
from sera_active_contracts import load_active_specs, main_float_constant

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
camera = (ROOT / "scripts/sera_camera_math.gd").read_text(encoding="utf-8")
project = (ROOT / "project.godot").read_text(encoding="utf-8")
spec = load_active_specs()
assert re.search(r'config/name="SERA v(\\d+)"', project) and int(re.search(r'config/name="SERA v(\\d+)"', project).group(1)) >= 318
assert spec["approved_at_version"] == 318
assert spec["ordinary_step"]["distance_m"] == 4
assert spec["ordinary_step"]["launch_warp_m"] == 0.3
for key in ("BACK_STEP_DISTANCE", "STEP_FORWARD_DISTANCE", "STEP_SIDE_DISTANCE",
            "STEP_MIN_ARC_LENGTH", "STEP_MAX_ARC_LENGTH"):
    assert main_float_constant(main, key) == 4, key
assert main_float_constant(main, "STEP_LAUNCH_WARP_DISTANCE") == 0.3
assert main_float_constant(main, "STEP_SPEED") == 15
assert main_float_constant(main, "SIDE_KICK_BOOST_DISTANCE") == 3
assert main_float_constant(main, "BACK_SOMERSAULT_DISTANCE") == 5
for name, value in (
    ("CAMERA_NORMAL_SIDE_ROOM_DEGREES", 22.0),
    ("CAMERA_STEP_ENTRY_SECONDS", 0.07),
    ("CAMERA_STEP_RECOVERY_HOLD_SECONDS", 0.06),
    ("CAMERA_STEP_RECOVERY_TOTAL_SECONDS", 0.30),
    ("CAMERA_MELEE_FOLLOW_ACCEL_SECONDS", 0.65),
    ("CAMERA_MELEE_FOLLOW_RELEASE_SECONDS", 0.18),
    ("CAMERA_MELEE_FOCUS_PEAK_RATE", 27.0),
    ("CAMERA_MELEE_YAW_PEAK_RATE", 20.0),
):
    assert main_float_constant(main, name) == value, name
start = main.split("func _start_omni_step(flick: Vector2) -> bool:", 1)[1].split(
    "func _start_back_step()", 1)[0]
assert "camera_step_recovery_active = false" in start
assert "camera_step_entry_elapsed = 0.0" in start
assert "_move_player_swept(world_step.normalized() * minf(" in start
assert "STEP_LAUNCH_WARP_DISTANCE, step_arc_length), false)" in start
assert "step_traveled_distance = launch_distance" in start
assert "step_elapsed = step_duration_current * clampf(" in start
assert "if side_kick_active:" in start
finish = main.split("func _finish_side_step(resume_moving: bool) -> void:", 1)[1].split(
    "func _kick_lock_center_xz()", 1)[0]
assert "if not side_kick_active:" in finish
assert "camera_step_recovery_active = true" in finish
render = main.split("func _process(delta: float) -> void:", 1)[1].split(
    "func _desired_camera_follow_focus_xz()", 1)[0]
assert render.index("_advance_camera_response_profile(delta)") < render.index("_advance_camera_follow_focus(delta)")
assert "camera_yaw = _adaptive_camera_yaw(bearing, delta)" in render
assert "and not camera_step_recovery_active" in render
assert "if hold_attack_camera or step_active or close_step_camera_this_frame:" in render
profile = main.split("func _advance_camera_response_profile(delta: float) -> void:", 1)[1].split(
    "func _adaptive_camera_yaw(", 1)[0]
for token in ("_combo_followup_input_window_open()", "back_somersault_active",
              "side_kick_active", "CAMERA_MELEE_FOLLOW_ACCEL_SECONDS",
              "CAMERA_MELEE_FOLLOW_RELEASE_SECONDS", "camera_melee_follow_weight = move_toward",
              "camera_step_recovery_elapsed = minf("):
    assert token in profile, token
yaw = main.split("func _adaptive_camera_yaw(player_bearing: float, delta: float) -> float:", 1)[1].split(
    "func _stable_shoulder_camera_yaw(", 1)[0]
for token in ("CAMERA_NORMAL_SIDE_ROOM_DEGREES", "CAMERA_PLAYER_YAW_FOLLOW_RATE",
              "CAMERA_MELEE_YAW_PEAK_RATE", "CAMERA_MATH.step_recovery_response(",
              "CAMERA_MATH.smooth_response(", "CAMERA_MATH.follow_yaw_with_side_room("):
    assert token in yaw, token
assert "follow_yaw_with_side_room(" in camera
assert "step_recovery_response(" in camera
assert "clampf(amount * alpha, -limit, limit)" in camera
assert "CAMERA_MELEE_FOCUS_PEAK_RATE" in main.split(
    "func _advance_camera_follow_focus(", 1)[1].split(
    "func _advance_camera_response_profile(", 1)[0]
assert "gd tools/v318_step_camera_runtime_check.gd" in (
    ROOT / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
print("V318_STEP_CAMERA_STATIC_PASS")
