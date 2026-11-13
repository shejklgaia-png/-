#!/usr/bin/env python3
"""v288: SERA-centred camera follows with short lag and hard distance/yaw leashes."""
from pathlib import Path
import math,re

R=Path(__file__).resolve().parents[1]
main=(R/"scripts/main.gd").read_text(encoding="utf-8")
math_code=(R/"scripts/sera_camera_math.gd").read_text(encoding="utf-8")
project=(R/"project.godot").read_text(encoding="utf-8")
assert int(re.search(r'config/name="SERA v(\d+)"',project).group(1))>=288
for token in (
    "CAMERA_PLAYER_FOCUS_LEAD_METERS: float = 2.0",
    "CAMERA_PLAYER_FOCUS_FOLLOW_RATE: float = 15.0",
    "CAMERA_PLAYER_FOCUS_MAX_LAG_METERS: float = 0.65",
    "CAMERA_PLAYER_YAW_FOLLOW_RATE: float = 10.0",
    "CAMERA_PLAYER_YAW_MAX_LAG_DEGREES: float = 12.0",
    "var camera_focus_follow_xz: Vector2 = Vector2.ZERO",
):
    assert token in main,token
desired=main.split("func _desired_camera_follow_focus_xz() -> Vector2:",1)[1].split(
    "func _advance_camera_follow_focus(",1)[0]
follow=main.split("func _advance_camera_follow_focus(delta: float) -> void:",1)[1].split(
    "func _stable_shoulder_camera_yaw(",1)[0]
yaw=main.split("func _stable_shoulder_camera_yaw(player_bearing: float, delta: float) -> float:",1)[1].split(
    "func _close_step_target_relative_yaw(",1)[0]
render=main.split("func _process(delta: float) -> void:",1)[1].split(
    "func _desired_camera_follow_focus_xz()",1)[0]
build=main.split("func _build_camera() -> void:",1)[1].split("func _build_overlay()",1)[0]
respawn=main.split("func _tick_training_ko(delta: float) -> void:",1)[1].split("func _advance_target_motion(",1)[0]
placement=main.split("func _place_camera() -> void:",1)[1].split("func _horizontal_safe(",1)[0]
analytic=main.split("func _minimum_boost_camera_radius() -> float:",1)[1].split(
    "func _camera_fit_release_speed()",1)[0]
assert "CAMERA_MATH.desired_follow_focus(" in desired
assert "(target_xz - player_xz).limit_length(lead)" in math_code
assert "return player_xz +" in math_code
assert "CAMERA_PLAYER_FOCUS_LEAD_METERS" in desired
assert "CAMERA_MATH.advance_follow_focus(" in follow
assert "current.lerp(desired, alpha)" in math_code
assert "CAMERA_PLAYER_FOCUS_FOLLOW_RATE" in follow
assert "CAMERA_PLAYER_FOCUS_MAX_LAG_METERS" in follow
assert "next = current + travel.normalized() * max_travel" in math_code
assert "CAMERA_PLAYER_YAW_FOLLOW_RATE" in yaw
assert "CAMERA_PLAYER_YAW_MAX_LAG_DEGREES" in yaw
assert "CAMERA_MATH.stable_shoulder_yaw(" in yaw
assert "return current_yaw + error - clampf(residual, -leash, leash)" in math_code
assert "camera_yaw = _stable_shoulder_camera_yaw(bearing, delta)" in render
assert "camera_yaw = _adaptive_camera_yaw(bearing, delta)" in render
assert "if separation > 0.08:" in render
assert "if hold_attack_camera or step_active or close_step_camera_this_frame:" in render
assert render.index("_advance_camera_follow_focus(delta)") < render.index("var radial: Vector2")
assert "_desired_camera_follow_focus_xz()" in build
assert "camera_focus_follow_xz = _desired_camera_follow_focus_xz()" in respawn
for proc in (placement,analytic):
    assert "camera_focus_follow_xz.x" in proc
    assert "TARGET_BASE_HEIGHT - CAMERA_FOCUS_DROP" in proc
    assert "camera_focus_follow_xz.y" in proc
assert "CAMERA_ELEVATION_RATIO * camera_radius" in placement
assert "CAMERA_COMBAT_ELEVATION_RATIO" not in main
assert "_visible_combat_camera_yaw" not in main
assert "if hold_attack_camera:" in render and "camera_dolly_in_speed = 0.0" in render
assert "_relax_camera_fit_radius(delta)" in render

# Mirror the bounded per-frame focus translation. A sudden player leap
# must not make the camera snap its entire former 0.65m error leash.
dt=1/60
x=0.0
for t in range(1,181):
    desired_x=0.0 if t<15 else (t-14)*0.24
    old_x=x
    next_x=x+(desired_x-x)*(1-math.exp(-15*dt))
    max_travel=max(16.0, 15*0.65*1.7)*dt
    x=x+max(-max_travel,min(max_travel,next_x-x))
    assert abs(x-old_x)<=max_travel+1e-9
    if t>70: assert x>0
yaw_old=0.0
for d in [0,1,5,14,30,60,110,160,195,-160,-130]:
    wanted=math.radians(d-12)
    delta=(wanted-yaw_old+math.pi)%(2*math.pi)-math.pi
    leftover=delta*math.exp(-10*dt)
    next_yaw=yaw_old+delta-max(-math.radians(12),min(math.radians(12),leftover))
    err=(wanted-next_yaw+math.pi)%(2*math.pi)-math.pi
    assert abs(err)<=math.radians(12)+1e-12
    yaw_old=next_yaw
print("V288_SERA_CAMERA_FOLLOW_STATIC_PASS")
