#!/usr/bin/env python3
"""Historical camera yaw guard remains; v340 replaces old kick orbit."""
import math,re
from pathlib import Path
r=Path(__file__).resolve().parents[1]
m=(r/"scripts/main.gd").read_text()
framing=(r/"scripts/sera_camera_framing.gd").read_text()
project=(r/"project.godot").read_text()
assert int(re.search(r'config/name="SERA v(\d+)"',project).group(1))>=340
assert "const STEP_CLOSE_CAMERA_MAX_RELATIVE_DEGREES: float = 45.0" in m
start=m.split("func _start_omni_step(flick: Vector2) -> bool:",1)[1].split("func _start_back_step(",1)[0]
advance=m.split("func _advance_side_step(delta: float) -> void:",1)[1].split("func _move_player_swept(",1)[0]
camera=m.split("func _process(delta: float) -> void:",1)[1].split("func _close_step_target_relative_yaw(",1)[0]
limit=m.split("func _close_step_target_relative_yaw(",1)[1].split("func _update_side_from_screen(",1)[0]
for token in ("step_linear_fallback = true","side_kick_active = step_kick_side_request != 0",
              "SIDE_KICK_MOTION_TIME_MULTIPLIER","SIDE_KICK_DURATION_REFERENCE_DISTANCE / step_speed_current",
              "side_kick_linear_direction = Vector2("):
    assert token in start,token
for token in ("_advance_homing_toward_target(second_chase_dt, SIDE_KICK_REACH)",
              "side_kick_linear_active = true","side_kick_linear_start_elapsed = step_elapsed",
              "side_kick_linear_direction * side_kick_linear_distance * line_progress"):
    assert token in advance,token
assert "_configure_side_kick_orbit" not in m
assert "if hold_attack_camera or step_active or close_step_camera_this_frame:" in camera
assert "CAMERA_FRAMING.close_step_target_relative_yaw(" in limit
assert "STEP_CLOSE_CAMERA_MAX_RELATIVE_DEGREES" in limit
assert "deg_to_rad(max_relative_degrees)" in framing
assert "STEP_CLOSE_CAMERA_MAX_TURN_RATE_DEGREES" in limit
assert "deg_to_rad(max_turn_degrees_per_second) * delta" in framing
for a in (-45,45): assert abs(math.degrees(math.radians(a))-a)<1e-9
print("V285_SIDE_KICK_CAMERA_STATIC_PASS (45deg guard, no orbit)")
