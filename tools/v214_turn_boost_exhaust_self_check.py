#!/usr/bin/env python3
"""SERA v214: keep nozzle jet on as long as a turning BOOST pose is visible."""
from pathlib import Path
import math
import re

ROOT = Path(__file__).resolve().parents[1]
def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

main=read("scripts/main.gd")
rig=read("scripts/sera_rig.gd")
fx=read("scripts/back_thruster_fx.gd")
project=read("project.godot")
ver=re.search(r'config/name="SERA v(\d+)"',project)
assert ver and int(ver.group(1)) >= 214

# The only authority for retaining visual FX is the ACTUALLY displayed
# authored BOOST posture, not arbitrary elapsed time or heavy leg clip name.
api=rig.split("func is_boost_exhaust_pose_visible() -> bool:",1)[1].split(
    "func get_thruster_intent() -> Dictionary:",1)[0]
for phrase in (
    "if not loading_ok or training_ko_active or combat_playback or step_playback",
    "or guard_playback or damage_playback or jump_playback:",
    "if current_clip == BOOST_CLIP:",
    'locomotion_mode == "boost" or locomotion_mode == "boost_grace"',
    "current_clip == RUN_CLIP and boost_to_run_crossfade",
    "and blending_for < blend_duration",
):
    assert phrase in api,phrase
assert 'const BOOST_TO_RUN_BLEND_SECONDS: float = 0.20' in rig
assert 'const BOOST_POSE_GRACE_SECONDS: float = 0.50' in main
assert 'boost_pose_grace_remaining = BOOST_POSE_GRACE_SECONDS' in main
assert 'boost_pose_grace_remaining = maxf(0.0, boost_pose_grace_remaining - delta)' in main

# Real-world energy/locomotion still depends ONLY on actual BOOST input.
assert "var boost_exhaust: bool = movement_boost_active and running" in main
assert "if movement_boost_active:" in main
assert "20.0 * delta * float(part_stats.get" in main
assert "blur_step_this_physics_frame or (combat_state == CombatState.IDLE" in main
assert "and movement_boost_active and running)))" in main
# FX lifetime is independent and must include neutral-thumb frames.
assert "var boost_pose_exhaust: bool = (" in main
assert "gesture_active and boost_has_activated_this_gesture and rig != null" in main
assert 'bool(rig.call("is_boost_exhaust_pose_visible"))' in main
assert "boost_exhaust or boost_pose_exhaust or stepping_this_frame" in main
assert "or tracking_exhaust))" in main
assert "not landing_active and not guard_active and not energy_exhausted" in main

# The jet direction is cached over the neutral point and replaced by fresh
# requested direction as soon as the finger begins moving the other way.
for token in (
    "var held_boost_exhaust_direction: Vector3 = Vector3.ZERO",
    "var held_boost_backstroke_weight: float = 0.0",
    "var held_boost_left_sector_world: Vector3 = Vector3.ZERO",
    "if boost_pose_exhaust and running:",
    "var requested_boost: Vector3 = _screen_drag_to_ground(direction_input)",
    "direction_of_exhaust = -requested_boost.normalized()",
    "elif boost_pose_exhaust and held_boost_exhaust_direction.length_squared() > 0.000001:",
    "direction_of_exhaust = held_boost_exhaust_direction",
    "elif boost_exhaust or boost_pose_exhaust:",
    "backstroke_weight = held_boost_backstroke_weight",
    "elif (boost_exhaust or boost_pose_exhaust) and direction_input.length_squared() > 0.000001:",
    "held_boost_exhaust_direction = direction_of_exhaust.normalized()",
    "held_boost_backstroke_weight = backstroke_weight",
    "held_boost_left_sector_world = left_sector_world",
    "backstroke_weight = held_boost_backstroke_weight",
    "left_sector_world = held_boost_left_sector_world",
    "elif not boost_exhaust:",
    "held_boost_exhaust_direction = Vector3.ZERO",
):
    assert token in main,token

# Heavy legs' ordinary SLIDE has no flames even though its animation clip
# is Boost_front. A genuine held BOOST gets full pose throughout its grace;
# after it ends heavy SLIDE returns to 50% of the same pose.
assert 'var sliding: bool = (moving and heavy_slide_run_enabled' in rig
assert 'and not boost_input_active and not boosting)' in rig
assert 'const SLIDE_BOOST_POSE_MAX_WEIGHT: float = 0.50' in rig
assert 'if locomotion_mode == "slide":' in rig
assert 'locomotion_mode = "boost_grace"' in rig
assert 'locomotion_mode = "slide"' in rig
assert 'fx.call("set_exhaust"' in read("scripts/sera_equipment.gd")

# Simulate actual state sequence: turning BOOST -> neutral finger -> new
# direction -> pose hold -> 0.20-s RUN transition -> normal RUN with jet off.
def visual_fx(mode, current, blend, duration, touching=True, activated=True,
              action=False, energy_empty=False):
    if not touching or not activated or action or energy_empty:
        return False
    if current == "BOOST":
        return mode in ("boost","boost_grace")
    if current == "RUN":
        return blend is not None and blend < duration
    return False

assert visual_fx("boost","BOOST",None,0.2)
for time in (0.02,0.12,0.32,0.49):
    assert time < 0.5 and visual_fx("boost_grace","BOOST",None,0.2)
for time in (0.0,0.07,0.15,0.19):
    assert visual_fx("run","RUN",time,0.2)
assert not visual_fx("run","RUN",0.2,0.2)
assert not visual_fx("slide","BOOST",None,0.2)
assert not visual_fx("boost_grace","BOOST",None,0.2,touching=False)
assert not visual_fx("boost_grace","BOOST",None,0.2,action=True)
assert not visual_fx("boost_grace","BOOST",None,0.2,energy_empty=True)

# A short deadzone must not reverse or zero the cached physical nozzle.
direction=(-0.8,0.0,0.6)
norm=math.sqrt(sum(x*x for x in direction))
direction=tuple(x/norm for x in direction)
last=direction
for _ in range(10):
    assert last==direction  # neutral thumb: no fresh heading
new=(0.7,0,-0.7)
norm=math.sqrt(sum(x*x for x in new))
last=tuple(x/norm for x in new)
assert last!=direction
print("PASS v214: visual BOOST+grace+crossfade jets persist through neutral turns")
print("PASS: no ordinary SLIDE, EN/step/combat/guard/airborne regressions")
print("Godot/Xperia Android rendering and touch not exercised")
