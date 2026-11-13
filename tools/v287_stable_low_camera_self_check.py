#!/usr/bin/env python3
"""v287 perspective remains low; v288 keeps SERA inside the yaw/distance leashes."""
from pathlib import Path
import math,re
R=Path(__file__).resolve().parents[1]
m=(R/"scripts/main.gd").read_text(encoding="utf-8")
math_code=(R/"scripts/sera_camera_math.gd").read_text(encoding="utf-8")
project=(R/"project.godot").read_text(encoding="utf-8")
assert int(re.search(r'config/name="SERA v(\d+)"',project).group(1)) >= 287
for const in (
    "const CAMERA_ELEVATION_RATIO: float = 0.21",
    "const CAMERA_COMBAT_YAW_HOLD_SECONDS: float = 0.45",
    "const CAMERA_COMBAT_SHOULDER_DEGREES: float = 12.0",
    "const CAMERA_COMBAT_MAX_PLAYER_SIDE_DEGREES: float = 30.0",
    "const CAMERA_PLAYER_YAW_FOLLOW_RATE: float = 10.0",
    "const CAMERA_PLAYER_YAW_MAX_LAG_DEGREES: float = 12.0",
    "const CAMERA_PLAYER_FOCUS_FOLLOW_RATE: float = 15.0",
    "const CAMERA_PLAYER_FOCUS_MAX_LAG_METERS: float = 0.65",
    "const CAMERA_COMBAT_MIN_RADIUS: float = 11.3",
    "const CAMERA_COMBAT_ZOOM_OUT_SPEED: float = 8.0",
    "var camera_combat_hold_remaining: float = 0.0",
):
    assert const in m,const
# v286 overhead angle and sample-based silhouette search are forbidden.
for old in ("CAMERA_COMBAT_ELEVATION_RATIO",
            "CAMERA_COMBAT_ELEVATION_FULL_DISTANCE",
            "camera_elevation_ratio_current",
            "CAMERA_COMBAT_YAW_SAMPLE_COUNT",
            "_visible_combat_camera_yaw"):
    assert old not in m,old
placement=m.split("func _place_camera() -> void:",1)[1].split(
    "func _horizontal_safe(",1)[0]
assert "CAMERA_ELEVATION_RATIO * camera_radius" in placement
assert "CAMERA_ELEVATION_RATIO" in m.split(
    "func _minimum_boost_camera_radius() -> float:",1)[1].split(
    "func _camera_fit_release_speed()",1)[0]
init=m.split("func _build_camera() -> void:",1)[1].split(
    "func _build_overlay() -> void:",1)[0]
assert "CAMERA_TARGET_COMPOSITION_SHOULDER_DEGREES" in init
assert "camera_composition_side = 1" in init
assert "_nearest_clear_yaw" not in init
helper=m.split("func _stable_shoulder_camera_yaw(player_bearing: float, delta: float) -> float:",1)[1].split(
    "func _close_step_target_relative_yaw(",1)[0]
assert "CAMERA_MATH.stable_shoulder_yaw(" in helper
assert "CAMERA_COMBAT_SHOULDER_DEGREES" in helper
assert "CAMERA_PLAYER_YAW_FOLLOW_RATE" in helper
assert "CAMERA_PLAYER_YAW_MAX_LAG_DEGREES" in helper
assert "bearing - deg_to_rad(shoulder_degrees)" in math_code
assert "wrapf(desired - current_yaw, -PI, PI)" in math_code
assert "-rate * maxf(delta, 0.0)" in math_code
assert "return current_yaw + error - clampf(residual, -leash, leash)" in math_code

cam=m.split("func _process(delta: float) -> void:",1)[1].split(
    "func _stable_shoulder_camera_yaw(",1)[0]
assert "or side_kick_active or back_somersault_active" in cam
assert "or landing_active or damage_reaction_active" in cam
assert "or hit_stop_remaining > 0.0" in cam
assert "camera_combat_hold_remaining = CAMERA_COMBAT_YAW_HOLD_SECONDS" in cam
assert "hold_attack_camera: bool = camera_combat_hold_remaining > 0.0" in cam
assert "if hold_attack_camera:" in cam
assert "camera_follow_radius = move_toward(" in cam
assert "CAMERA_COMBAT_MIN_RADIUS" in cam
assert "camera_dolly_in_speed = 0.0" in cam
assert "if hold_attack_camera or step_active or close_step_camera_this_frame:" in cam
assert "_fit_boost_frame_analytically(delta)" in cam
assert "camera_yaw = _adaptive_camera_yaw(bearing, delta)" in cam
assert "camera_yaw = _visible_combat_camera_yaw" not in cam
assert "camera_elevation_ratio_current" not in cam
assert "CAMERA_COMBAT_ELEVATION_RATIO" not in cam
assert "_nearest_clear_yaw(" not in cam
assert "CAMERA_COMBAT_VISIBILITY_DISTANCE" in cam

kick=m.split("func _configure_side_kick_orbit() -> void:",1)[1].split(
    "func _advance_side_step(",1)[0]
for token in (
    "step_target_center = _kick_lock_center_xz()",
    "step_start_offset = radial",
    "tangent.dot(screen_right_xz)",
    "side_kick_orbit_sign",
    "STEP_CLOSE_ORBIT_MAX_DEGREES",
    "side_kick_linear_distance = maxf(0.0,",
    "SIDE_KICK_BOOST_DISTANCE - radius * absf(step_signed_angle)",
):
    assert token in kick,token
step=m.split("func _advance_side_step(delta: float) -> void:",1)[1].split(
    "func _move_player_swept(",1)[0]
assert "step_start_offset.rotated(" in step
assert "side_kick_linear_direction * side_kick_linear_distance * line_progress" in step
assert "SIDE_KICK_HIT_PROGRESS.size()" in step
assert "progress >= second_windup" in step
# v300 removes the obsolete 30deg orbital plan bound; the independent
# camera constraint still limits SERA/camera target bearing to 45deg.
assert "const STEP_CLOSE_CAMERA_MAX_RELATIVE_DEGREES: float = 45.0" in m
for radius in (0.1,0.5,1.,3.,9.):
    arc=min(1.125/radius, math.radians(120.))*radius
    assert arc<=1.125+1e-12 and 3.-arc>=0.
# The 12deg hard leash prevents the 90deg sideways angle that v287's
# fixed camera could accumulate during a fast series of melee actions.
yaw=0.0
for target_deg in (0,8,16,35,80,98,120,140):
    desired=math.radians(target_deg-12)
    error=(desired-yaw+math.pi)%(2*math.pi)-math.pi
    alpha=1-math.exp(-10.0/60)
    residual=error*(1-alpha)
    leash=math.radians(12)
    yaw+=error-max(-leash,min(leash,residual))
    assert abs((desired-yaw+math.pi)%(2*math.pi)-math.pi)<=leash+1e-10
print("V287_STABLE_LOW_CAMERA_STATIC_PASS")
