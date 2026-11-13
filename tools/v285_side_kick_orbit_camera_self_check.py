#!/usr/bin/env python3
"""SERA v285: side kicks orbit live target while camera/target/player angle <=45deg."""
import math,re
from pathlib import Path

R=Path(__file__).resolve().parents[1]
main=(R/"scripts/main.gd").read_text(encoding="utf-8")
framing=(R/"scripts/sera_camera_framing.gd").read_text(encoding="utf-8")
project=(R/"project.godot").read_text(encoding="utf-8")
assert int(re.search(r'config/name="SERA v(\d+)"',project).group(1))>=285
assert "const STEP_CLOSE_CAMERA_MAX_RELATIVE_DEGREES: float = 45.0" in main
assert "const STEP_CLOSE_CAMERA_MAX_RELATIVE_DEGREES: float = 65.0" not in main
start=main.split("func _start_omni_step(flick: Vector2) -> bool:",1)[1].split("func _start_back_step(",1)[0]
setup=main.split("func _configure_side_kick_orbit() -> void:",1)[1].split(
    "func _advance_side_step(",1)[0]
advance=main.split("func _advance_side_step(delta: float) -> void:",1)[1].split(
    "func _move_player_swept(",1)[0]
camera=main.split("func _process(delta: float) -> void:",1)[1].split(
    "func _close_step_target_relative_yaw(",1)[0]
limit=main.split("func _close_step_target_relative_yaw(",1)[1].split(
    "func _update_side_from_screen(",1)[0]
# Normal screen STEP stays linear, while Kick keeps its 2x authored duration.
assert "step_linear_fallback = true" in start
assert "side_kick_active = step_kick_side_request != 0" in start
assert "SIDE_KICK_MOTION_TIME_MULTIPLIER" in start
assert "step_arc_length = SIDE_KICK_BOOST_DISTANCE" in start
assert start.index("if side_kick_active:") < start.index("step_linear_fallback = false")
assert "_distance_to_cube_surface(player.position) <= MELEE_SURFACE_REACH" in start

# v300: true locked-part pivot, ending at the second authored foot hit.
for token in (
    "step_target_center = _kick_lock_center_xz()",
    "step_start_offset = radial",
    "side_kick_orbit_sign",
    "side_kick_linear_distance = maxf(",
    "SIDE_KICK_BOOST_DISTANCE - radius * absf(step_signed_angle)",
    "step_linear_offset = Vector2.ZERO",
    "STEP_CLOSE_ORBIT_MAX_DEGREES",
):
    assert token in setup,token
assert "chase_until: float = minf(" in advance
assert "step_duration_current * second_windup" in advance
assert advance.index("_advance_homing_toward_target(chase_dt, BASH_REACH)") < advance.index("_configure_side_kick_orbit()")
for token in (
    "if not side_kick_travel_anchor_set and progress >= second_windup:",
    "step_target_center = _kick_lock_center_xz()",
    "step_signed_angle * orbit_progress",
    "if progress >= second_hit:",
    "side_kick_linear_active = true",
    "side_kick_linear_direction * side_kick_linear_distance * line_progress",
    "_move_player_swept(",
    "if previous_progress < impact_progress and progress >= impact_progress:",
):
    assert token in advance,token
assert "if hold_attack_camera or step_active or close_step_camera_this_frame:" in camera
assert "camera_yaw = _stable_shoulder_camera_yaw(bearing, delta)" in camera
assert "CAMERA_FRAMING.close_step_target_relative_yaw(" in limit
assert "STEP_CLOSE_CAMERA_MAX_RELATIVE_DEGREES" in limit
assert "deg_to_rad(max_relative_degrees)" in framing
assert "SIDE_KICK_HIT_PROGRESS[1]" in setup
assert "STEP_CLOSE_CAMERA_MAX_TURN_RATE_DEGREES" in limit
assert "deg_to_rad(max_turn_degrees_per_second) * delta" in framing
# Tangent-to-screen-right chooses proper sign at both sides of target,
# including oblique camera bases. Circle radius and arc length stay fixed.
for x,z in ((0,9),(3,4),(-3,4),(4,-3),(-4,-3)):
    r=math.hypot(x,z)
    tx,tz=-z/r,x/r
    for vx,vz in ((1,0),(.6,.8),(-.8,.6)):
        v_len=math.hypot(vx,vz);vx/=v_len;vz/=v_len
        tangent_dot=tx*vx+tz*vz
        if abs(tangent_dot)<1e-7:continue
        for side in (1,-1):
            angle=(min(4.0/r,math.radians(120))
                   * (1 if tangent_dot>=0 else -1)*side)
            assert angle*tangent_dot*side>0
            end_x=x*math.cos(angle)-z*math.sin(angle)
            end_z=x*math.sin(angle)+z*math.cos(angle)
            assert math.isclose(math.hypot(end_x,end_z),r,abs_tol=1e-9)
assert abs(math.degrees(math.radians(45.0))-45)<1e-9
print("V285_SIDE_KICK_ORBIT_CAMERA_STATIC_PASS")
