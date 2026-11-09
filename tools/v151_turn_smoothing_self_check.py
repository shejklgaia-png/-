#!/usr/bin/env python3
"""v151: circular direction filtering, single-heading RUN gait/yaw and BOOST.

These are source and mathematical checks, not Godot or Android playback.
"""
import math
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
rig = (root / "scripts/sera_rig.gd").read_text(encoding="utf-8")
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
overlay = (root / "scripts/touch_overlay.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
assert re.findall(r'^config/name="([^"]+)"$', project, re.MULTILINE) == ["SERA v152"]
assert (root / "README_v151_ja.md").is_file()

def region(name, next_name):
    return rig.split("func " + name, 1)[1].split("func " + next_name, 1)[0]

initial = region("_set_run_motion_direction(local_direction: Vector2) -> void:",
                 "_update_run_retreat_mode(")
sector = region("_update_run_retreat_mode(direction: Vector2) -> void:",
                "_run_yaw_for_direction(")
yaw = region("_run_yaw_for_direction(direction: Vector2, retreat_weight: float) -> float:",
             "_smooth_visual_direction(")
angle = region("_smooth_visual_direction(current: Vector2, target: Vector2,",
               "get_run_dominant_clip(")
process = region("_process(delta: float) -> void:", "_run_heading_from_weights(")
assert "const RUN_DIRECTION_BLEND_SECONDS: float = 0.055" in rig
assert "const BOOST_DIRECTION_BLEND_SECONDS: float = 0.045" in rig
assert "const RUN_MODE_BLEND_SECONDS: float = 0.085" in rig
assert "const RUN_ROOT_TURN_SPEED_DEGREES: float = 1440.0" in rig
assert "const RUN_MODE_HYSTERESIS_DEGREES: float = 5.0" in rig
assert "const VISUAL_TURN_DEADBAND_DEGREES: float = 3.0" in rig
assert "const VISUAL_OPPOSITE_TURN_BAND_DEGREES: float = 12.0" in rig
assert "run_direction_target = direction" in initial
assert "run_retreat_mode = false" in sector
assert "run_retreat_mode = true" in sector
assert "run_retreat_mode =" not in initial.rsplit("run_direction_target = direction",1)[-1]
assert "run_retreat_mode = (_run_input_angle_degrees(direction)" in initial
assert "PI * retreat_weight" in yaw
assert "angle_now: float = atan2(current.x, current.y)" in angle
assert "angle_goal: float = atan2(target.x, target.y)" in angle
assert "wrapf(angle_goal - angle_now, -PI, PI)" in angle
assert "absf(absf(angle_delta) - PI)" in angle
assert "angle_delta = absf(angle_delta) * updated_sign" in angle
assert "absf(angle_delta) > deg_to_rad(VISUAL_TURN_DEADBAND_DEGREES)" in angle
assert "Vector2(sin(new_angle), cos(new_angle))" in angle
assert "run_direction_smoothed.lerp(" not in rig
assert "run_direction_smoothed = run_update[\"heading\"]" in process
assert "boost_direction_smoothed = boost_update[\"heading\"]" in process
assert "run_turn_sign = run_update[\"turn_sign\"]" in process
assert "boost_turn_sign = boost_update[\"turn_sign\"]" in process
assert process.index("run_direction_smoothed = run_update") < process.index(
    "_update_run_retreat_mode(heading)") < process.index(
    "run_retreat_blend = lerpf(") < process.index(
    "_run_yaw_for_direction(heading, run_retreat_blend)")
assert "var bank_axis: Vector3 = facing * Vector3.BACK" in rig
assert "RUN_HEAD_SWAY_RETENTION: float = 0.35" in rig

# Gameplay steering and controller HUD must be completely unaffected.
assert "var segment: Vector2 = pos - pointer_location" in main
assert "direction_input = next_heading" in main
assert "SWIPE_HEADING_SAMPLE_PIXELS: float = 12.0" in main
assert "SWIPE_BOOST_TRAVEL_PIXELS: float = 140.0" in main
assert "player.velocity = world_move * MOVE_SPEED * GROUND_MOVE_SPEED_SCALE * (" in main
assert "MOVEMENT_BOOST_MULTIPLIER if movement_boost_active else 1.0" in main
assert 'rig.call("set_moving", running, movement_boost_active, local_run_direction)' in main
assert "const SWIPE_HEADING_FOLLOW_SECONDS: float = 0.052" in overlay
assert "visual_heading_angle = lerp_angle(" in overlay
assert "JUMP_TOUCH_INPUT_ENABLED: bool = false" in main
assert "const STRIKE_DAMAGE = [12, 12, 26]" in main

def wrap(value):
    return (value + math.pi) % (2.0*math.pi) - math.pi

def advance(current, target, dt, tau, last_sign):
    current_angle = math.atan2(current[0], current[1])
    target_angle = math.atan2(target[0], target[1])
    angle_delta = wrap(target_angle - current_angle)
    new_sign = last_sign
    if abs(abs(angle_delta)-math.pi) < math.radians(12):
        angle_delta = abs(angle_delta)*new_sign
    elif abs(angle_delta)>0.0001:
        new_sign = 1.0 if angle_delta>0 else -1.0
    next_angle = current_angle
    if abs(angle_delta)>math.radians(3):
        next_angle += angle_delta*(1.0-math.exp(-max(0.0,dt)/tau))
    return (math.sin(next_angle),math.cos(next_angle)),new_sign

# 180°: never shrink to a zero vector and never flip in a single frame.
for degrees in (90.0, 180.0, 179.9, -179.9, -90.0):
    direction = (math.sin(math.radians(degrees)),math.cos(math.radians(degrees)))
    smoothed=(0.0,1.0)
    turn_sign=1.0
    traversed=[]
    for _ in range(30):
        smoothed,turn_sign=advance(smoothed,direction,1/60,0.055,turn_sign)
        assert abs(math.hypot(*smoothed)-1.0)<1e-12
        traversed.append(math.atan2(smoothed[0],smoothed[1]))
    assert abs(wrap(traversed[0]))<math.radians(50)
    assert abs(wrap(math.atan2(direction[0],direction[1])-traversed[-1]))<math.radians(3.1)

# Tiny 2° target motion remains in visual deadband, not gameplay deadband.
still,sign=advance((0.,1.),(math.sin(math.radians(2)),math.cos(math.radians(2))),
                   1/60,0.055,1.)
assert still==(0.,1.)

# ±180° jitter shouldn't reverse the model's rotation direction each frame.
smooth=(0.,1.)
sign=1.
angles=[]
for i in range(15):
    deg=179.5 if i%2==0 else -179.5
    smooth,sign=advance(smooth, (math.sin(math.radians(deg)),
                               math.cos(math.radians(deg))), 1/60,.055,sign)
    angle=math.atan2(smooth[0],smooth[1])
    angles.append(angle)
assert all(angles[i]>angles[i-1] for i in range(1,12))
assert angles[9]>math.radians(168)

# The forward/backward authored gait and Waist yaw evolve on the SAME
# smoothed heading. A clip transition never injects an immediate 180° jump.
heading=math.radians(105)
previous=None
for i in range(21):
    weight=i/20
    yaw=wrap(-heading-math.pi*weight)
    if previous is not None:
        assert abs(wrap(yaw-previous))<=math.radians(9.1)
    previous=yaw
# Existing handedness bias and ±5° gate should be preserved.
def retreat(mode, angle, center):
    if mode:
        return not (angle < center-5)
    return angle > center+5
assert not retreat(False, 104,100) and retreat(False,106,100)
assert retreat(True,96,100) and not retreat(True,94,100)
assert not retreat(False,124,120) and retreat(False,126,120)
print("v151 continuous RUN/BOOST rotations and synchronized gait/yaw: STATIC+MATH PASS")
print("Godot parser, physical controller and Xperia visuals: NOT TESTED")
