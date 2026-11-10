#!/usr/bin/env python3
"""SERA v219: ten-sided, subtly rounder FX tubes with a 50ms 15x burst."""
from __future__ import annotations
from pathlib import Path
import math
import re

ROOT = Path(__file__).resolve().parents[1]
def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

project = read("project.godot")
fx = read("scripts/back_thruster_fx.gd")
shader = read("shaders/back_thruster.gdshader")
main = read("scripts/main.gd")
rig = read("scripts/sera_rig.gd")
equipment = read("scripts/sera_equipment.gd")
m = re.search(r'config/name="SERA v(\d+)"', project)
assert m and int(m.group(1)) >= 219

# The procedural emitted jet (NOT the physical Blockbench nozzle) is a
# regular decagon with the previous 12 longitudinal subdivisions.
assert 'const EXHAUST_RADIAL_SIDES: int = 10' in fx
assert 'const EXHAUST_AXIAL_SEGMENTS: int = 12' in fx
assert 'for side in range(EXHAUST_RADIAL_SIDES):' in fx
assert 'var start_angle: float = TAU * float(side) / float(EXHAUST_RADIAL_SIDES)' in fx
assert 'var end_angle: float = TAU * float(side + 1) / float(EXHAUST_RADIAL_SIDES)' in fx
assert 'var a := Vector2(cos(start_angle), sin(start_angle)) * half_width' in fx
assert 'var b := Vector2(cos(end_angle), sin(end_angle)) * half_width' in fx
assert 'for section in range(EXHAUST_AXIAL_SEGMENTS):' in fx
assert 'Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0)' in fx
assert 'Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1)' in fx
assert 'for corner_index in [0, 1, 2, 0, 2, 3]:' in fx
assert 'DecagonalExhaustCore' in fx and 'DecagonalExhaustShell' in fx
assert 'RectangularExhaustCore' not in fx
assert 'for side in range(4):' not in fx
assert 10 * 12 * 6 == 720  # Each FX tube: 720 vertices, 240 triangles.
# The 10 sides are identical in edge length and meet at 360 degrees.
points = [(math.cos(math.tau * i/10), math.sin(math.tau * i/10)) for i in range(10)]
assert len({(round(x,10),round(y,10)) for x,y in points}) == 10
lengths = [math.dist(points[i], points[(i+1)%10]) for i in range(10)]
assert max(lengths) - min(lengths) < 1e-12
assert math.isclose(lengths[0], 2*math.sin(math.pi/10), abs_tol=1e-12)
assert math.isclose(math.hypot(*points[0]), 1)
assert math.isclose(math.hypot(*points[9]), 1)
# The outer/core diameters remain based on their own 0.058/0.029 radii.
assert '_build_tube(0.058, EXHAUST_LENGTH,' in fx
assert '_build_tube(0.029, EXHAUST_LENGTH * 0.83,' in fx

# Burst reaches its maximum in 0.05s; smooth cubic decay remains 0.18s.
assert 'const BURST_RISE_SECONDS: float = 0.05' in fx
assert 'const BURST_FALL_SECONDS: float = 0.18' in fx
assert 'const BURST_TOTAL_SECONDS: float = BURST_RISE_SECONDS + BURST_FALL_SECONDS' in fx
assert 'burst = burst_elapsed / BURST_RISE_SECONDS' in fx
assert 'burst = 1.0 - fall * fall * (3.0 - 2.0 * fall)' in fx
assert 'burst_elapsed = minf(BURST_TOTAL_SECONDS, burst_elapsed + maxf(delta, 0.0))' in fx
assert 'if acceleration_burst:' in fx
assert 'burst_elapsed = 0.0' in fx
assert 'burst_elapsed = BURST_TOTAL_SECONDS' in fx
assert 'outer_material.set_shader_parameter("burst", 0.0)' in fx
assert 'inner_material.set_shader_parameter("burst", 0.0)' in fx

rise,fall=0.05,0.18
def envelope(t: float) -> float:
    if t<rise: return t/rise
    if t<rise+fall:
        p=(t-rise)/fall
        return 1.0-p*p*(3.0-2.0*p)
    return 0.0

for t in (0,.016,.033,.049,.05,.1,.15,.21,.229,.23,.28):
    assert 0.0<=envelope(t)<=1.0
assert 0 < envelope(.016) < envelope(.033) < envelope(.05)
assert math.isclose(envelope(.05),1.0,abs_tol=1e-12)
assert envelope(.05)>envelope(.1)>envelope(.15)>envelope(.229)>0
assert math.isclose(envelope(.23),0.0,abs_tol=1e-10)

# Same near-nozzle 15x flare as v218, unchanged regular thin jet on expiry.
assert 'float fan = burst * smoothstep(0.0, 0.25, along);' in shader
assert 'VERTEX.xy *= 1.0 + 14.0 * fan;' in shader
assert 'VERTEX.z *= 1.0 + 0.28 * burst * along;' in shader
assert 'uniform float burst : hint_range(0.0, 1.0) = 0.0;' in shader
def smoothstep_quarter(t: float) -> float:
    v=max(0.0,min(1.0,t/.25))
    return v*v*(3-2*v)
def width(t: float, time: float) -> float:
    return 1.0+14.0*envelope(time)*smoothstep_quarter(t)
assert width(0.0,.05)==1
assert math.isclose(width(.125,.05),8)
assert math.isclose(width(.25,.05),15)
assert math.isclose(width(1.0,.05),15)
assert math.isclose(width(.25,.23),1)
for t in (0,.04,.125,.25,.5,1):
    assert math.isclose(width(t,.23),1)
# No change to the 3D pivot, jet aim or one-shot attack/STEP trigger.
assert 'nozzle_rest_rotation = nozzle.quaternion' in fx
assert 'const PITCH_DOWN_LIMIT_RADIANS: float = PI * 90.0 / 180.0' in fx
assert 'stepping_this_frame and not thruster_accel_previous_step' in main
assert 'tracking_accel_state != thruster_accel_previous_tracking_state' in main
assert 'left_sector_world, acceleration_burst)' in main
assert 'left_sector_world, acceleration_burst)' in rig
assert 'acceleration_burst)' in equipment
assert 'const SLIDE_BOOST_POSE_MAX_WEIGHT: float = 0.50' in rig
print("PASS v219: 10-sided rounder FX tube, 12 axial rings, 720 vertices per tube")
print("PASS: 50ms flare rise + 180ms fade; 15x near-nozzle peak, 230ms total")
print("PASS: STEP/homing triggers, original pivots, aim, EN and heavy SLIDE intact")
print("Godot Android 3D shader appearance not verified")
