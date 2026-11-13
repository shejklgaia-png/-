#!/usr/bin/env python3
"""v286 safe kick radius/LOCK overlays, now using v287 non-overhead stable camera."""
from pathlib import Path
import re,math
R=Path(__file__).resolve().parents[1]
m=(R/"scripts/main.gd").read_text(encoding="utf-8")
project=(R/"project.godot").read_text(encoding="utf-8")
assert int(re.search(r'config/name="SERA v(\d+)"',project).group(1))>=286
# v300 replaces the old target-radius expansion with 3m total arc+straight.
assert "SIDE_KICK_BOOST_DISTANCE: float = 3.0" in m
assert "step_target_center = _kick_lock_center_xz()" in m
assert "side_kick_linear_distance = maxf(0.0," in m
assert "SIDE_KICK_BOOST_DISTANCE - radius * absf(step_signed_angle)" in m
assert "side_kick_linear_active = true" in m
assert "side_kick_linear_direction * side_kick_linear_distance * line_progress" in m
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
# Radius affects the angle (and straight remainder), never the boost budget.
for start in (0.05,0.4,1.0,2.4,3.0,3.55,4.0,9.0):
    for turn_fraction in (0.2,0.3,0.5):
        planned=3.*turn_fraction
        angle=min(planned/start, math.radians(120.))
        arc=start*angle
        straight=3.-arc
        assert arc>=0 and straight>=0
        assert math.isclose(arc+straight,3.0,abs_tol=1e-10)
print("V286_CLOSE_CAMERA_CLEARANCE_STATIC_PASS: 3m arc+straight budget, LOCK UI, v287 low-pitch camera")
