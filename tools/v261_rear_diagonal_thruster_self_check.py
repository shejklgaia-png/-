#!/usr/bin/env python3
"""v261: left/rear diagonal thruster keeps backstroke's downward nozzle priority."""
from pathlib import Path
import math
import re

R=Path(__file__).resolve().parents[1]
def read(path):return (R/path).read_text(encoding="utf-8")
main=read("scripts/main.gd")
fx=read("scripts/back_thruster_fx.gd")
project=read("project.godot")
v=re.search(r'^config/name="SERA v(\d+)"$',project,re.M)
assert v and int(v.group(1))>=261
assert (R/"README_v261_ja.md").is_file()
assert "v261 rear-diagonal BOOST nozzle fix" in read("AGENTS.md")
assert "v261 — 左斜め後退" in read("docs/SERA_INPUT_MOVEMENT_CAMERA.md")
motion=main.split("var backstroke_weight: float = 0.0",1)[1].split(
    'rig.call("update_back_thruster_fx"',1)[0]
assert "backstroke_weight = clampf(step_world_rear.dot(" in motion
assert "player.global_transform.basis.z), 0.0, 1.0)" in motion
assert "backstroke_weight = clampf(step_flick_this_frame.y, 0.0, 1.0)" in motion
assert "intended_boost.normalized().dot(" in motion
assert "player.global_transform.basis.z), 0.0, 1.0)" in motion
assert "leftward_weight = clampf(-direction_input.normalized().x, 0.0, 1.0)" in motion
assert "leftward_weight = clampf(-step_flick_this_frame.x, 0.0, 1.0)" in motion
assert "left_sector_world = Vector3.DOWN.slerp(" in motion
assert "screen_right, leftward_weight * 0.50).normalized()" in motion
assert "left_sector_world = left_sector_world.slerp(" in motion
assert "Vector3.DOWN, backstroke_weight).normalized()" in motion
assert motion.index("screen_right, leftward_weight * 0.50).normalized()") < motion.index(
    "Vector3.DOWN, backstroke_weight).normalized()")
assert "held_boost_left_sector_world = left_sector_world" in motion
assert "left_sector_world = held_boost_left_sector_world" in motion
assert "left_sector_world, acceleration_burst, normal_melee_exhaust)" in main

# Real physical nozzle follows the blended target, with old authored
# pivot/servo, world-downwash and special camera sector unchanged.
for term in ("if enabled and left_sector_world.length_squared() > 0.000001:",
             "rest_basis.inverse() * left_sector_world.normalized()",
             "local_sector_direction = _with_lift_downwash(",
             "Quaternion(Vector3.BACK, local_sector_direction)",
             "nozzle.quaternion = nozzle.quaternion.slerp(",
             "returning_from_screen_sector = true",
             "steering_yaw = lerp_angle(steering_yaw, yaw, ease)",
             "steering_pitch = lerp_angle(steering_pitch, pitch, ease)",
             "LIFT_DOWNWASH_WEIGHT: float = 0.40",
             "RIBBON_LIFETIME_SECONDS: float = 0.34"):
    assert term in fx,term

# The DOWN->SCREEN_RIGHT sector is an arc in the plane of gravity and
# camera screen-right. Spherical interpolation by BACKSTROKE must reduce
# the visible rightward angle monotonically, independent of camera yaw.
def aim(left_weight,back_weight,camera_yaw=0.0):
    theta=(math.pi/4)*left_weight*(1-back_weight)
    c,s=math.cos(camera_yaw),math.sin(camera_yaw)
    return (math.sin(theta)*c,-math.cos(theta),math.sin(theta)*s)

for cam_yaw in (-2.8,-1.1,0.0,0.8,2.4):
    right=(math.cos(cam_yaw),0.0,math.sin(cam_yaw))
    for left in (0.01,0.25,0.50,math.sqrt(0.5),0.90,1.0):
        prev=math.inf
        for back in (0.0,0.1,0.25,0.50,math.sqrt(0.5),0.75,0.9,1.0):
            vec=aim(left,back,cam_yaw)
            dot_right=vec[0]*right[0]+vec[2]*right[2]
            # Always camera down/right, never camera up/left.
            assert dot_right >= -1e-10 and vec[1] < 0
            assert math.isclose(sum(v*v for v in vec),1.0,abs_tol=1e-10)
            angle=math.atan2(dot_right,-vec[1])
            assert -1e-10 <= angle <= math.pi/4 + 1e-10
            assert angle <= prev + 1e-10,(cam_yaw,left,back,angle,prev)
            assert math.isclose(angle,(math.pi/4)*left*(1-back),abs_tol=1e-9)
            prev=angle
        assert abs(aim(left,1.0,cam_yaw)[1]+1.0)<1e-10
    assert math.isclose(aim(1.0,0.0,cam_yaw)[1],-math.sqrt(.5),abs_tol=1e-10)
# The 45-degree BACK-LEFT diagonal now has only ~9.3 degrees of screen
# rightward nozzle aim, instead of the previous ~31.8 degrees.
b=1/math.sqrt(2)
diagonal_angle=math.degrees((math.pi/4)*b*(1-b))
assert 9.2<diagonal_angle<9.4,diagonal_angle
old_angle=math.degrees((math.pi/4)*b)
assert old_angle>31.0
# World downwash adds still more gravity; it cannot rotate rightward.
for l in (.3,1.0):
    for b in (.2,.7,.95):
        vec=aim(l,b)
        biased=(vec[0],vec[1]-.4,vec[2])
        mag=math.sqrt(sum(v*v for v in biased))
        assert math.atan2(biased[0]/mag,-biased[1]/mag) <= math.atan2(vec[0],-vec[1])+1e-10
assert "const SECTOR_COUNT: int = 4" in read("scripts/flick_direction_policy.gd")
assert "not _combo_followup_input_window_open()" in main
assert "return FLICK_DIRECTION_POLICY.screen_step_direction(displacement)" in main
print("PASS v261: pure left and full reverse preserved; rear-left diagonals increasingly point DOWN")
print("PASS v261: all camera yaw angles, world-down lift bias, servo, trail, melee and input unchanged")
print("Static/numerical checks only; Android rendering not tested")
