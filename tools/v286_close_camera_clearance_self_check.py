#!/usr/bin/env python3
"""v286: prevent SERA from being hidden behind the target after close Kick_l/r."""
from pathlib import Path
import re,math
R=Path(__file__).resolve().parents[1]
m=(R/"scripts/main.gd").read_text(encoding="utf-8")
p=(R/"project.godot").read_text(encoding="utf-8")
assert int(re.search(r'config/name="SERA v(\d+)"',p).group(1))>=286

for token in (
    "SIDE_KICK_SAFE_ORBIT_RADIUS: float = 3.55",
    "CAMERA_COMBAT_VISIBILITY_DISTANCE: float = 6.0",
    "CAMERA_COMBAT_ELEVATION_FULL_DISTANCE: float = 3.7",
    "CAMERA_COMBAT_ELEVATION_RATIO: float = 0.82",
    "CAMERA_COMBAT_ELEVATION_RESPONSE: float = 5.0",
    "CAMERA_COMBAT_YAW_SAMPLE_COUNT: int = 9",
    "STEP_CLOSE_CAMERA_MAX_RELATIVE_DEGREES: float = 45.0",
    "camera_elevation_ratio_current: float = CAMERA_ELEVATION_RATIO",
    "LOCK_CONTROLS_VERTICAL_RATIO: float = 0.76",
    "CONTROLLER_REGION_START_RATIO: float = 0.50",
):
    assert token in m,token
orbit=m.split("func _configure_side_kick_orbit() -> void:",1)[1].split(
    "func _advance_side_step(",1)[0]
advance=m.split("func _advance_side_step(delta: float) -> void:",1)[1].split(
    "func _move_player_swept(",1)[0]
assert "step_radial_delta = maxf(0.0, SIDE_KICK_SAFE_ORBIT_RADIUS - radius)" in orbit
assert "step_arc_length / maxf(radius, SIDE_KICK_SAFE_ORBIT_RADIUS)" in orbit
assert "step_linear_fallback = radius < min_orbit_radius" in orbit
assert "smoothstep(0.0, 0.65, travel_progress)" in advance
assert "step_radial_delta * radial_progress" in advance
assert "_move_player_swept(requested, true)" in advance
assert "step_target_center = Vector2(target.position.x, target.position.z)" in advance
assert "SIDE_KICK_SECOND_WINDUP_R" in advance and "SIDE_KICK_SECOND_WINDUP_L" in advance
assert "if previous_progress < impact_progress and progress >= impact_progress:" in advance

camera=m.split("func _process(delta: float) -> void:",1)[1].split(
    "func _close_step_target_relative_yaw(",1)[0]
visibility=m.split("func _visible_combat_camera_yaw(player_bearing: float, delta: float) -> float:",1)[1].split(
    "func _close_step_target_relative_yaw(",1)[0]
assert "if step_active and side_kick_active and separation > 0.08:" in camera
assert "camera_yaw = _visible_combat_camera_yaw(bearing, delta)" in camera
assert "if separation <= CAMERA_COMBAT_VISIBILITY_DISTANCE:" in camera
assert "camera_yaw = _visible_combat_camera_yaw(bearing, delta)" in camera
assert "camera_elevation_ratio_current = lerpf(" in camera
assert "CAMERA_COMBAT_ELEVATION_RESPONSE * maxf(delta, 0.0)" in camera
assert "CAMERA_COMBAT_VISIBILITY_DISTANCE, separation" in camera
assert "player_bearing - float(side) * max_angle * t" in visibility
assert "var gap: float = _signed_screen_gap(side)" in visibility
assert "if gap >= wanted_gap:" in visibility
assert "var turn_limit: float" in visibility
assert "return previous_yaw + clampf(yaw_error, -turn_limit, turn_limit)" in visibility
assert "CAMERA_COMBAT_YAW_SAMPLE_COUNT" in visibility
placement=m.split("func _place_camera() -> void:",1)[1].split(
    "func _horizontal_safe(",1)[0]
assert "camera_elevation_ratio_current * camera_radius" in placement
# Even a kick that starts against the wide legs moves OUT, never pops.
for start in (1.0,2.4,3.0,3.55,4.0,9.0):
    radial=max(0.0,3.55-start)
    for t in (0.0,0.2,0.5,0.65,1.0):
        f=max(0.0,min(1.0,t/0.65))
        f=f*f*(3-2*f)
        radius=start+radial*f
        assert radius>=start-1e-9
        assert radius<=max(start,3.55)+1e-9
    assert math.isclose(start+radial,max(start,3.55),abs_tol=1e-10)
print("V286_CLOSE_CAMERA_CLEARANCE_STATIC_PASS")
