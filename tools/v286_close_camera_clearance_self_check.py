#!/usr/bin/env python3
"""v286 safe kick radius/LOCK overlays, now using v287 non-overhead stable camera."""
from pathlib import Path
import re,math
R=Path(__file__).resolve().parents[1]
m=(R/"scripts/main.gd").read_text(encoding="utf-8")
project=(R/"project.godot").read_text(encoding="utf-8")
assert int(re.search(r'config/name="SERA v(\d+)"',project).group(1))>=286
assert "SIDE_KICK_SAFE_ORBIT_RADIUS: float = 3.55" in m
assert "step_radial_delta = maxf(0.0, SIDE_KICK_SAFE_ORBIT_RADIUS - radius)" in m
assert "step_arc_length / maxf(radius, SIDE_KICK_SAFE_ORBIT_RADIUS)" in m
assert "smoothstep(0.0, 0.65, travel_progress)" in m
assert "step_radial_delta * radial_progress" in m
assert "_move_player_swept(requested, true)" in m
for token in (
    "LOCK_CONTROLS_VERTICAL_RATIO: float = 0.76",
    "CONTROLLER_REGION_START_RATIO: float = 0.50",
    "button.anchor_top = LOCK_CONTROLS_VERTICAL_RATIO",
    "lock_mode_button.anchor_top = LOCK_CONTROLS_VERTICAL_RATIO",
    "button.anchor_left = CONTROLLER_REGION_START_RATIO",
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
for start in (1.0,2.4,3.0,3.55,4.0,9.0):
    radial=max(0.0,3.55-start)
    for t in (0.0,0.2,0.5,0.65,1.0):
        f=max(0.0,min(1.0,t/0.65));f=f*f*(3-2*f)
        r=start+radial*f
        assert start-1e-9<=r<=max(3.55,start)+1e-9
print("V286_CLOSE_CAMERA_CLEARANCE_STATIC_PASS: safe radius and LOCK UI, v287 fixed low-pitch camera")
