#!/usr/bin/env python3
"""SERA v210: backward BOOST/STEP steer the physical nozzle down."""
from __future__ import annotations
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

main = read("scripts/main.gd")
rig = read("scripts/sera_rig.gd")
equip = read("scripts/sera_equipment.gd")
fx = read("scripts/back_thruster_fx.gd")
project = read("project.godot")
version = re.search(r'config/name="SERA v([0-9]+)"', project)
assert version is not None and int(version.group(1)) >= 210

# Backward input: use the requested motion, not the velocity after collision.
for needle in (
    "var backstroke_weight: float = 0.0",
    "if stepping_this_frame:",
    "backstroke_weight = clampf(step_flick_this_frame.y, 0.0, 1.0)",
    "step_side_this_frame == STEP_BACK and step_flick_this_frame.is_zero_approx()",
    "elif boost_exhaust:",
    "var intended_boost: Vector3 = _screen_drag_to_ground(direction_input)",
    "player.global_transform.basis.z), 0.0, 1.0)",
    "direction_of_exhaust.normalized(), delta, backstroke_weight)",
    "var step_flick_this_frame: Vector2 = step_flick_direction",
):
    assert needle in main, needle
assert "var boost_exhaust: bool = movement_boost_active and running" in main

# End-to-end transport: controller -> rig -> selected equipment -> real pivots.
for source, needle in (
    (rig, "delta: float, backstroke_weight: float = 0.0) -> void:"),
    (rig, "active, exhaust_world, delta, backstroke_weight)"),
    (equip, "delta: float, backstroke_weight: float = 0.0) -> void:"),
    (equip, "exhaust_world, delta, backstroke_weight)"),
    (fx, "delta: float, backstroke_weight: float = 0.0) -> void:"),
    (fx, "var backstroke: float = clampf(backstroke_weight, 0.0, 1.0)"),
    (fx, "yaw = lerpf(yaw, 0.0, backstroke)"),
    (fx, "pitch = lerpf(pitch, PITCH_DOWN_LIMIT_RADIANS, backstroke)"),
    (fx, "nozzle.quaternion = (nozzle_rest_rotation"),
    (fx, "Quaternion(Vector3.RIGHT, steering_pitch)"),
    (fx, "const PITCH_DOWN_LIMIT_RADIANS: float = PI * 90.0 / 180.0"),
    (fx, "const PITCH_UP_LIMIT_RADIANS: float = PI * 1.0 / 180.0"),
    (fx, "const YAW_LIMIT_RADIANS: float = PI * 80.0 / 180.0"),
):
    assert needle in source, needle

YAW_LIMIT = math.radians(80)
UP_LIMIT = math.radians(1)
DOWN_LIMIT = math.radians(90)
def nozzle_target(x: float, y: float, z: float, backstroke: float):
    denominator = max(z, 0.0) + 2.0 * max(-z, 0.0) + 0.02
    yaw = max(-YAW_LIMIT, min(YAW_LIMIT, math.atan2(x, denominator)))
    pitch = max(-UP_LIMIT, min(DOWN_LIMIT,
                               -math.atan2(y, math.hypot(x, z))))
    alpha = max(0.0, min(1.0, backstroke))
    return yaw * (1.0 - alpha), pitch * (1.0 - alpha) + DOWN_LIMIT * alpha

for x,y,z in ((0,0,-1),(1,0,-1),(-1,0,-1)):
    yaw,pitch=nozzle_target(x,y,z,1.0)
    assert math.isclose(yaw,0.0,abs_tol=1e-10)
    assert math.isclose(pitch,DOWN_LIMIT,abs_tol=1e-10)

# Partially backward movement holds the chosen lateral direction and pitches.
left=nozzle_target(-1,0,-1,0.5)
right=nozzle_target(1,0,-1,0.5)
assert left[0] < 0 < right[0]
assert math.isclose(left[1],math.radians(45),abs_tol=1e-10)
assert math.isclose(right[1],math.radians(45),abs_tol=1e-10)
for alpha in (0.0,0.1,0.25,0.5,0.75,0.9,1.0):
    yaw,pitch=nozzle_target(0.3,0,-1,alpha)
    assert -YAW_LIMIT <= yaw <= YAW_LIMIT
    assert -UP_LIMIT <= pitch <= DOWN_LIMIT
    assert math.isclose(pitch, DOWN_LIMIT*alpha,abs_tol=1e-10)

# Non-backward BOOST, lateral STEP, and tracking (weight=0) are unchanged.
for direction in ((0,0,1),(1,0,0),(-1,0,0),(0.3,0.4,0.5)):
    assert nozzle_target(*direction,0.0) == nozzle_target(*direction,-1.0)

print("PASS v210: BOOST/STEP rearward thrust aims nozzles down by 90 degrees")
print("PASS: diagonal smooth blending, existing yaw/pitch limits, authored pivots")
print("Godot Android visualization not verified")
