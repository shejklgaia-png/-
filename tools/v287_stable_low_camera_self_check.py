#!/usr/bin/env python3
"""v287: camera stays low and stable across repeated attacks, player not side-on."""
from pathlib import Path
import math,re
R=Path(__file__).resolve().parents[1]
m=(R/"scripts/main.gd").read_text(encoding="utf-8")
project=(R/"project.godot").read_text(encoding="utf-8")
assert int(re.search(r'config/name="SERA v(\d+)"',project).group(1)) >= 287
for const in (
    "const CAMERA_ELEVATION_RATIO: float = 0.21",
    "const CAMERA_COMBAT_YAW_HOLD_SECONDS: float = 0.45",
    "const CAMERA_COMBAT_SHOULDER_DEGREES: float = 12.0",
    "const CAMERA_COMBAT_MAX_PLAYER_SIDE_DEGREES: float = 30.0",
    "const CAMERA_COMBAT_IDLE_YAW_RESPONSE: float = 0.9",
    "const CAMERA_COMBAT_IDLE_YAW_MAX_SPEED_DEGREES: float = 32.0",
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
assert "start_bearing - deg_to_rad(CAMERA_COMBAT_SHOULDER_DEGREES)" in init
assert "_nearest_clear_yaw" not in init
helper=m.split("func _stable_shoulder_camera_yaw(player_bearing: float, delta: float) -> float:",1)[1].split(
    "func _close_step_target_relative_yaw(",1)[0]
assert "player_bearing - deg_to_rad(" in helper
assert "CAMERA_COMBAT_SHOULDER_DEGREES" in helper
assert "wrapf(desired - camera_yaw, -PI, PI)" in helper
assert "-CAMERA_COMBAT_IDLE_YAW_RESPONSE * maxf(delta, 0.0)" in helper
assert "CAMERA_COMBAT_IDLE_YAW_MAX_SPEED_DEGREES" in helper
assert "clampf(error * alpha, -max_turn, max_turn)" in helper

cam=m.split("func _process(delta: float) -> void:",1)[1].split(
    "func _stable_shoulder_camera_yaw(",1)[0]
assert "or side_kick_active or back_somersault_active" in cam
assert "or landing_active or hit_stop_remaining > 0.0" in cam
assert "camera_combat_hold_remaining = CAMERA_COMBAT_YAW_HOLD_SECONDS" in cam
assert "hold_attack_camera: bool = camera_combat_hold_remaining > 0.0" in cam
assert "if hold_attack_camera:" in cam
assert "camera_follow_radius = move_toward(" in cam
assert "CAMERA_COMBAT_MIN_RADIUS" in cam
assert "camera_dolly_in_speed = 0.0" in cam
assert "if hold_attack_camera or step_active or close_step_camera_this_frame:" in cam
assert "if not hold_attack_camera:" in cam
assert "_relax_camera_fit_radius(delta)" in cam
assert "camera_yaw = _stable_shoulder_camera_yaw(bearing, delta)" in cam
assert "camera_yaw = _visible_combat_camera_yaw" not in cam
assert "camera_elevation_ratio_current" not in cam
assert "CAMERA_COMBAT_ELEVATION_RATIO" not in cam
assert "_nearest_clear_yaw(" not in cam
assert "CAMERA_COMBAT_VISIBILITY_DISTANCE" in cam

kick=m.split("func _configure_side_kick_orbit() -> void:",1)[1].split(
    "func _advance_side_step(",1)[0]
for token in ("start_bearing: float = atan2(radial.x, radial.y)",
              "relative_start: float = wrapf(start_bearing - camera_yaw, -PI, PI)",
              "deg_to_rad(CAMERA_COMBAT_MAX_PLAYER_SIDE_DEGREES)",
              "allowed: float = clampf(step_signed_angle,",
              "step_signed_angle = allowed if allowed * orbit_sign > 0.0 else 0.0",
              "SIDE_KICK_SAFE_ORBIT_RADIUS",
              "tangent.dot(screen_right_xz)"):
    assert token in kick,token
step=m.split("func _advance_side_step(delta: float) -> void:",1)[1].split(
    "func _move_player_swept(",1)[0]
assert "smoothstep(0.0, 0.65, travel_progress)" in step
assert "_move_player_swept(requested, true)" in step
assert "SIDE_KICK_HIT_PROGRESS.size()" in step
assert "if progress >= second_windup:" in step

# A fixed-yaw kick can never move farther out than 30deg relative to camera.
for initial in (-60,-30,-12,0,12,30,60):
    for raw in (-90,-55,-30,30,55,90):
        allowed=max(-30-initial,min(30-initial,raw))
        arc=allowed if allowed*raw>0 else 0.0
        if -30<=initial<=30:
            assert abs(initial+arc)<=30+1e-12
        assert arc*raw>=-1e-12
# Independent of FPS, a 32deg/s smoothing cap prevents sudden yaw turns.
yaw=0.0
for _ in range(60):
    error=math.radians(90-12)-yaw
    alpha=1-math.exp(-0.9/60)
    step=max(-math.radians(32)/60,min(math.radians(32)/60,error*alpha))
    assert abs(step)<=math.radians(32)/60+1e-12
    yaw+=step
assert 0<math.degrees(yaw)<=32
print("V287_STABLE_LOW_CAMERA_STATIC_PASS")
