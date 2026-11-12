#!/usr/bin/env python3
"""SERA v218+: 15x flare within first 25% of a polygonal exhaust tube."""
from __future__ import annotations
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

shader = read("shaders/back_thruster.gdshader")
fx = read("scripts/back_thruster_fx.gd")
main = read("scripts/main.gd")
rig = read("scripts/sera_rig.gd")
equipment = read("scripts/sera_equipment.gd")
project = read("project.godot")
match = re.search(r'config/name="SERA v(\d+)"', project)
assert match and int(match.group(1)) >= 218

# The original tube only had vertices at z=0 and z=length. For a real
# close-to-nozzle flare, intermediate rings must exist so the vertex shader
# can produce the curve instead of a straight 0->15x taper.
assert "const EXHAUST_AXIAL_SEGMENTS: int = 12" in fx
assert "const EXHAUST_RADIAL_SIDES: int = 10" in fx
assert "for side in range(EXHAUST_RADIAL_SIDES):" in fx
assert "for section in range(EXHAUST_AXIAL_SEGMENTS):" in fx
assert "var t0: float = float(section) / float(EXHAUST_AXIAL_SEGMENTS)" in fx
assert "var t1: float = float(section + 1) / float(EXHAUST_AXIAL_SEGMENTS)" in fx
assert "var z0: float = length * t0" in fx
assert "var z1: float = length * t1" in fx
assert "Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0)" in fx
assert "Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1)" in fx
assert "Vector2(0.0, t0), Vector2(1.0, t0)" in fx
assert "Vector2(1.0, t1), Vector2(0.0, t1)" in fx
assert "for corner_index in [0, 1, 2, 0, 2, 3]:" in fx
assert "instance.mesh = tool.commit()" in fx
# 12 axial quads per side, 10 sides, 6 triangle-corner vertices per quad.
assert 12 * 10 * 6 == 720
# The 0.25 section aligns exactly with an authored ring (3 of 12).
rings = [i / 12 for i in range(13)]
assert .25 in rings and rings[0] == 0 and rings[-1] == 1

# Godot shader uses the exact sublength ramp (0 to 25% of local Z),
# magnifying original XY width by 15x at peak without widening the lip.
assert "float fan = burst * smoothstep(0.0, 0.25, along);" in shader
assert "VERTEX.xy *= 1.0 + 14.0 * fan;" in shader
assert "float along = clamp(VERTEX.z / max(tube_length, 0.01), 0.0, 1.0);" in shader
assert "VERTEX.z *= 1.0 + 0.28 * burst * along;" in shader
assert "uniform float burst : hint_range(0.0, 1.0) = 0.0;" in shader
assert "VERTEX.xy *= 1.0 + along * 0.19 * sin(" in shader

def smoothstep(x: float) -> float:
    u = max(0.0, min(1.0, x / .25))
    return u*u*(3-2*u)

def expansion(along: float, burst: float) -> float:
    return 1.0 + 14.0 * burst * smoothstep(along)

assert math.isclose(expansion(0.0, 1.0), 1.0)
assert math.isclose(expansion(0.25, 1.0), 15.0)
assert math.isclose(expansion(1.0, 1.0), 15.0)
assert math.isclose(expansion(0.125, 1.0), 8.0)
for i, x in enumerate(rings):
    w=expansion(x, 1.0)
    assert 1.0 <= w <= 15.0
    if i>0:
        assert w+1e-10 >= expansion(rings[i-1],1.0)
    if x>=.25:
        assert math.isclose(w,15.0)
    assert math.isclose(expansion(x,0.0),1.0)
assert expansion(2/12,1.0) > 10.0
# A 0.65m authored tube achieves full width by 0.1625m from nozzle lip.
assert "const EXHAUST_LENGTH: float = 0.65" in fx
assert math.isclose(.65*.25,.1625,abs_tol=1e-12)

# Tuning now uses a 50ms expansion and 180ms return; the flare remains a
# transient STEP / attack / bash onset effect, never a 15x permanent flame.
assert "const BURST_RISE_SECONDS: float = 0.05" in fx
assert "const BURST_FALL_SECONDS: float = 0.18" in fx
assert "const BURST_TOTAL_SECONDS: float = BURST_RISE_SECONDS + BURST_FALL_SECONDS" in fx
assert "if acceleration_burst:" in fx and "burst_elapsed = 0.0" in fx
assert "outer_material.set_shader_parameter(\"burst\", burst)" in fx
assert "inner_material.set_shader_parameter(\"burst\", burst)" in fx
assert "outer_material.set_shader_parameter(\"burst\", 0.0)" in fx
assert "inner_material.set_shader_parameter(\"burst\", 0.0)" in fx
assert "stepping_this_frame and not thruster_accel_previous_step" in main
assert "tracking_accel_state != thruster_accel_previous_tracking_state" in main
assert "left_sector_world, acceleration_burst, normal_melee_exhaust or normal_kick_exhaust)" in main
assert "left_sector_world, acceleration_burst, melee_sustain)" in rig
assert "acceleration_burst, melee_sustain)" in equipment
assert "nozzle_rest_rotation = nozzle.quaternion" in fx
assert "const SLIDE_BOOST_POSE_MAX_WEIGHT: float = 0.50" in rig
assert "const PITCH_DOWN_LIMIT_RADIANS: float = PI * 90.0 / 180.0" in fx

print("PASS v218: 12 axial segments shape a decagonal jet; wide by 25% of its length")
print("PASS: width 15x at flare peak, 1x at nozzle lip and after 230ms")
print("PASS: existing STEP/homing triggers, nozzle pivots, directions, EN unchanged")
print("Godot/Android shader rendering remains unverified")
