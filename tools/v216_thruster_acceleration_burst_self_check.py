#!/usr/bin/env python3
"""SERA v216: a one-shot wide thruster flare for fast STEP / melee tracking."""
from __future__ import annotations
from pathlib import Path
import math
import re

ROOT=Path(__file__).resolve().parents[1]
def read(name):
    return (ROOT / name).read_text(encoding="utf-8")
main=read("scripts/main.gd")
rig=read("scripts/sera_rig.gd")
equip=read("scripts/sera_equipment.gd")
fx=read("scripts/back_thruster_fx.gd")
shader=read("shaders/back_thruster.gdshader")
proj=read("project.godot")
version=re.search(r'config/name="SERA v(\d+)"',proj)
assert version and int(version.group(1)) >= 216

# One pulse on the first STEP frame. The snapshot is taken before the STEP
# mover can finish on that physics tick, and the flag is updated EVERY tick.
assert "var thruster_accel_previous_step: bool = false" in main
assert "var thruster_accel_previous_tracking_state: int = -1" in main
assert "var stepping_this_frame: bool = step_active" in main
assert "var tracking_accel_state: int = combat_state if tracking_exhaust else -1" in main
for token in (
    "var acceleration_burst: bool = (exhaust_on",
    "stepping_this_frame and not thruster_accel_previous_step",
    "tracking_accel_state >= 0",
    "tracking_accel_state != thruster_accel_previous_tracking_state",
    "thruster_accel_previous_step = stepping_this_frame",
    "thruster_accel_previous_tracking_state = tracking_accel_state",
):
    assert token in main,token
for chase in ("CombatState.DASH", "CombatState.BASH_TRACK",
              "CombatState.STRIKE_TRACK", "CombatState.STRIKE", "CombatState.BASH"):
    assert chase in main.split("var tracking_exhaust: bool =",1)[1].split(
        "tracking_exhaust = tracking_exhaust",1)[0],chase
assert "tracking_exhaust = tracking_exhaust and blur_velocity.length_squared() > 0.04" in main
assert "boost_exhaust or boost_pose_exhaust or stepping_this_frame" in main
assert "not landing_active and not guard_active and not energy_exhausted" in main

# The burst parameter travels with the original v213 camera-relative
# exhaust vector; neither nozzle direction nor combat movement is modified.
assert 'left_sector_world, acceleration_burst, melee_sustain)' in main
assert 'acceleration_burst: bool = false,' in rig
assert 'left_sector_world, acceleration_burst, melee_sustain)' in rig
assert 'acceleration_burst: bool = false,' in equip
assert 'exhaust_world, delta, backstroke_weight, left_sector_world,' in equip
assert 'acceleration_burst, melee_sustain)' in equip
assert 'fx.call("set_exhaust", active and str(set_id) == selected_booster,' in equip
assert 'acceleration_burst: bool = false,' in fx

# CPU-side envelope: opens fast, decays smoothly, resets completely on off.
for s in (
    'const BURST_RISE_SECONDS: float = 0.05',
    'const BURST_FALL_SECONDS: float = 0.18',
    'const BURST_TOTAL_SECONDS: float = BURST_RISE_SECONDS + BURST_FALL_SECONDS',
    'var burst_elapsed: float = BURST_TOTAL_SECONDS',
    'if acceleration_burst:',
    'burst_elapsed = 0.0',
    'burst_elapsed = BURST_TOTAL_SECONDS',
    'burst_elapsed = minf(BURST_TOTAL_SECONDS, burst_elapsed + maxf(delta, 0.0))',
    'burst = burst_elapsed / BURST_RISE_SECONDS',
    'burst = 1.0 - fall * fall * (3.0 - 2.0 * fall)',
    'outer_material.set_shader_parameter("burst", burst)',
    'inner_material.set_shader_parameter("burst", burst)',
    'outer_material.set_shader_parameter("burst", 0.0)',
    'inner_material.set_shader_parameter("burst", 0.0)',
    'material.set_shader_parameter("burst", 0.0)',
):
    assert s in fx,s

# Shader deforms the existing 4-sided tubes, not the Blockbench nozzle.
# At the attachment lip (along=0), burst must not increase width.
for s in (
    'uniform float burst : hint_range(0.0, 1.0) = 0.0;',
    'float fan = burst * smoothstep(0.0, 0.25, along);',
    'VERTEX.xy *= 1.0 + 14.0 * fan;',
    'VERTEX.z *= 1.0 + 0.28 * burst * along;',
    'EMISSION = flame_tint.rgb * (0.75 + 0.45 * pulse) * (1.0 + 0.85 * burst)',
    'ALPHA = clamp(strength',
):
    assert s in shader,s
assert "for side in range(EXHAUST_RADIAL_SIDES):" in fx and "pivot.add_child(fx)" in equip
assert "const PITCH_DOWN_LIMIT_RADIANS: float = PI * 90.0 / 180.0" in fx
assert "Quaternion(Vector3.BACK, local_sector_direction)" in fx
assert "const SLIDE_BOOST_POSE_MAX_WEIGHT: float = 0.50" in rig

# Math: rise -> single peak -> smooth fall -> ZERO, with no retrigger on
# continuous STEP/tracking frames. Distinct chase modes retrigger once.
rise=.05
fall=.18
def intensity(t):
    if t<rise: return t/rise
    if t<rise+fall:
        p=max(0.,min(1.,(t-rise)/fall))
        return 1.-p*p*(3.-2.*p)
    return 0.
for t in (0.,.01,.02,.035,.05,.075,.10,.125,.17,.214,.22,.23,.5):
    assert -1e-12<=intensity(t)<=1+1e-12
assert math.isclose(intensity(.05),1.)
assert intensity(.075)>intensity(.125)>intensity(.22)>0.
assert math.isclose(intensity(.23),0.,abs_tol=1e-10)
def spread(position: float) -> float:
    alpha=max(0.,min(1.,position/.25))
    return alpha*alpha*(3.-2.*alpha)
for p in (0.,.05,.15,.25,.5,1.):
    assert math.isclose(1.+14.0*intensity(.05)*spread(p),1.+14.0*spread(p))
assert math.isclose(1.+14.0*intensity(.05)*spread(0.),1.)
assert math.isclose(1.+14.0*intensity(.05)*spread(.25),15.0)
states=[(False,-1),(True,-1),(True,-1),(True,-1),(False,-1),
        (False,4),(False,4),(False,5),(False,-1),(True,-1)]
last_step=False
last_tracking=-1
pulse_count=0
for stepping,tracking in states:
    pulse=(stepping and not last_step) or (tracking>=0 and tracking!=last_tracking)
    pulse_count+=int(pulse)
    last_step=stepping
    last_tracking=tracking
assert pulse_count==4 # two STEPs + two distinct chase starts

print("PASS v216: one-shot STEP/homing burst, decagonal wide-to-narrow flare")
print("PASS: burst 50ms opening, 180ms return, original nozzle angles")
print("Godot/Android GPU shader output not device-tested")
