#!/usr/bin/env python3
"""SERA v217: jet-tip size 5x, 100ms expansion, 180ms return."""
from __future__ import annotations
from pathlib import Path
import math
import re

ROOT = Path(__file__).resolve().parents[1]
def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

fx=read("scripts/back_thruster_fx.gd")
shader=read("shaders/back_thruster.gdshader")
main=read("scripts/main.gd")
rig=read("scripts/sera_rig.gd")
equipment=read("scripts/sera_equipment.gd")
project=read("project.godot")
version=re.search(r'config/name="SERA v(\d+)"',project)
assert version and int(version.group(1)) >= 217

assert "const BURST_RISE_SECONDS: float = 0.10" in fx
assert "const BURST_FALL_SECONDS: float = 0.18" in fx
assert "const BURST_TOTAL_SECONDS: float = BURST_RISE_SECONDS + BURST_FALL_SECONDS" in fx
assert "burst_elapsed = minf(BURST_TOTAL_SECONDS, burst_elapsed + maxf(delta, 0.0))" in fx
assert "burst = burst_elapsed / BURST_RISE_SECONDS" in fx
assert "burst = 1.0 - fall * fall * (3.0 - 2.0 * fall)" in fx
assert 'if acceleration_burst:' in fx
assert 'burst_elapsed = 0.0' in fx
assert 'burst_elapsed = BURST_TOTAL_SECONDS' in fx
assert 'outer_material.set_shader_parameter("burst", burst)' in fx
assert 'inner_material.set_shader_parameter("burst", burst)' in fx
assert 'outer_material.set_shader_parameter("burst", 0.0)' in fx
assert 'inner_material.set_shader_parameter("burst", 0.0)' in fx
assert "uniform float burst : hint_range(0.0, 1.0) = 0.0;" in shader
assert "float fan = burst * smoothstep(0.0, 0.25, along);" in shader
assert "VERTEX.xy *= 1.0 + 14.0 * fan;" in shader
assert "VERTEX.z *= 1.0 + 0.28 * burst * along;" in shader
assert "EMISSION = flame_tint.rgb * (0.75 + 0.45 * pulse) * (1.0 + 0.85 * burst);" in shader
assert 'for side in range(4):' in fx

rise,fall=.10,.18
def envelope(t: float) -> float:
    if t < rise:
        return t / rise
    if t < rise + fall:
        p=(t-rise)/fall
        return 1.-p*p*(3.-2.*p)
    return 0.

for t in (0,.01,.05,.0999,.10,.12,.20,.27,.28,.40):
    assert 0. <= envelope(t) <= 1., t
assert math.isclose(envelope(.10),1.,abs_tol=1e-12)
assert math.isclose(envelope(.28),0.,abs_tol=1e-12)
assert 0 < envelope(.01) < envelope(.05) < envelope(.10)
assert envelope(.10) > envelope(.12) > envelope(.20) > envelope(.27) > 0.
# The v217 temporal rise/decay and unchanged nozzle lip remain guaranteed.
# v218 explicitly raises the flare's maximum size from 5x to 15x.
def spread(position: float) -> float:
    q=max(0.,min(1.,position/.25))
    return q*q*(3.-2.*q)
for amount in (0., .25, .5, .75, 1.):
    assert math.isclose(1.+14.*amount*spread(0.),1.)
    assert 1.+14.*amount*spread(1.) >= 1.+4.*amount
assert math.isclose(1. + 14.*envelope(.10)*spread(1.),15.0)
assert math.isclose(1. + 14.*envelope(.10)*spread(0.),1.0)
assert math.isclose(1. + 14.*envelope(.28)*spread(1.),1.0)
# Original one-shot behavior and physical nozzle geometry remain unaffected.
assert 'stepping_this_frame and not thruster_accel_previous_step' in main
assert 'tracking_accel_state != thruster_accel_previous_tracking_state' in main
assert 'left_sector_world, acceleration_burst)' in main
assert 'left_sector_world, acceleration_burst)' in rig
assert 'acceleration_burst)' in equipment
assert "nozzle_rest_rotation = nozzle.quaternion" in fx
assert "const PITCH_DOWN_LIMIT_RADIANS: float = PI * 90.0 / 180.0" in fx
assert "const SLIDE_BOOST_POSE_MAX_WEIGHT: float = 0.50" in rig
print("PASS v217: 100ms expansion, 180ms smooth fall, 280ms total; tip now >=5x")
print("PASS: nozzle mouth, existing STEP/melee triggers, angles, EN unchanged")
print("Godot Android shader rendering not verified")
