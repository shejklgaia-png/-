#!/usr/bin/env python3
"""v286 safe kick radius/LOCK overlays, now using v287 non-overhead stable camera."""
from sera_active_contracts import load_active_specs, main_float_constant
from pathlib import Path
import re,math
R=Path(__file__).resolve().parents[1]
m=(R/"scripts/main.gd").read_text(encoding="utf-8")
project=(R/"project.godot").read_text(encoding="utf-8")
assert int(re.search(r'config/name="SERA v(\d+)"',project).group(1))>=286
# v300 replaces the old target-radius expansion with 3m total arc+straight.
assert main_float_constant(m, "SIDE_KICK_BOOST_DISTANCE") == load_active_specs()["side_kick"]["distance_m"]
assert "side_kick_linear_distance = SIDE_KICK_BOOST_DISTANCE" in m
assert "side_kick_linear_active = true" in m
assert "side_kick_linear_direction * side_kick_linear_distance * line_progress" in m
assert "step_signed_angle = 0.0" in m
assert "step_start_offset.rotated(" not in m
assert "_move_player_swept(" in m
for token in (
    "LOCK_CONTROLS_VERTICAL_RATIO: float = 0.76",
    "CONTROLLER_REGION_START_RATIO: float = 0.50",
    "button.anchor_top = LOCK_CONTROLS_VERTICAL_RATIO",
    "lock_mode_button.anchor_top = LOCK_CONTROLS_VERTICAL_RATIO",
    "button.anchor_left = base",
):
    assert token in m,token
# v287 reverts the pitch and silhouette-scan portions of v286: both were
# responsible for disorienting 3/4-profile views and per-strike shaking.
assert "const CAMERA_ELEVATION_RATIO: float = 0.21" in m
assert "CAMERA_COMBAT_ELEVATION_RATIO" not in m
assert "camera_elevation_ratio_current" not in m
assert "_visible_combat_camera_yaw" not in m
assert "CAMERA_COMBAT_MAX_PLAYER_SIDE_DEGREES: float = 30.0" in m
assert "CAMERA_COMBAT_YAW_HOLD_SECONDS: float = 0.45" in m
print("V286_CLOSE_CAMERA_CLEARANCE_STATIC_PASS: approved straight kick, LOCK UI, low-pitch camera")
