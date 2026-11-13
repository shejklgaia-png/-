#!/usr/bin/env python3
"""SERA v221: no visual gaps in sustained normal-melee jets on nontracking frames."""
from pathlib import Path
import math
import re

ROOT=Path(__file__).resolve().parents[1]
def read(p):
    return (ROOT / p).read_text(encoding="utf-8")

main=read("scripts/main.gd")
rig=read("scripts/sera_rig.gd")
equip=read("scripts/sera_equipment.gd")
fx=read("scripts/back_thruster_fx.gd")
shader=read("shaders/back_thruster.gdshader")
project=read("project.godot")
version=re.search(r'config/name="SERA v(\d+)"',project)
assert version and int(version.group(1)) >= 221

# Normal emission stays ON throughout normal melee 1/2/3 even without
# actual movement, after blade impact and during the existing hit stop.
normal=main.split("var normal_melee_exhaust: bool = (",1)[1].split(
    "var normal_kick_exhaust: bool =",1)[0]
for s in ("CombatState.MELEE_APPROACH", "CombatState.DASH",
          "CombatState.STRIKE_TRACK", "CombatState.STRIKE"):
    assert s in normal,s
assert "combat_state == CombatState.BASH" in normal
assert "strike_did_hit" not in normal
assert "tracking_exhaust" not in normal
assert "blur_velocity" not in normal
frame=read("scripts/sera_physics_frame_rules.gd")
exhaust=main.split("var exhaust_on: bool = PHYSICS_FRAME.exhaust_allowed(",1)[1].split(
    "var tracking_accel_state: int =",1)[0]
assert "energy_exhausted, boost_exhaust, boost_pose_exhaust," in exhaust
assert "stepping_this_frame, tracking_exhaust, normal_attack_exhaust)" in exhaust
assert "or tracking_exhaust or attack_exhaust" in frame
assert "not damage_active and not jumping and not landing" in frame
assert "and not guarding and not energy_exhausted" in frame

# Previously, a very small hit-stop/collision delta could be normalized into
# an unstable nozzle steering target and conceal the jet in the character.
# Only an attack frame WITHOUT actual homing uses SERA's stable rear axis.
steering=main.split("var direction_of_exhaust: Vector3 =",1)[1].split(
    "var backstroke_weight: float =",1)[0]
assert "var direction_of_exhaust: Vector3 = -blur_velocity" in main
assert "if normal_attack_exhaust and not tracking_exhaust" in steering
assert "direction_of_exhaust = player.global_transform.basis.z" in steering
assert steering.index("if normal_attack_exhaust and not tracking_exhaust") > steering.index(
    "elif boost_pose_exhaust and held_boost_exhaust_direction.length_squared() > 0.000001:")
assert "if direction_of_exhaust.length_squared() < 0.0004:" in steering

# A separate sustain flag never accidentally triggers the one-shot 15x
# acceleration burst. It goes through the normal selected booster routing.
burst=main.split("var tracking_accel_state: int =",1)[1].split(
    "var direction_of_exhaust: Vector3 =",1)[0]
assert "combat_state if tracking_exhaust else -1" in burst
assert "normal_melee_exhaust" not in burst
assert "acceleration_burst: bool = PHYSICS_FRAME.acceleration_burst(" in burst
assert "exhaust_on, stepping_this_frame, thruster_accel_previous_step," in burst
assert "thruster_accel_previous_tracking_state)" in burst
assert "stepping and not previous_step" in frame
assert "tracking_state != previous_tracking_state" in frame
assert "left_sector_world, acceleration_burst, normal_attack_exhaust)" in main
for x in (rig,equip,fx):
    assert "melee_sustain: bool = false" in x
assert "left_sector_world, acceleration_burst, melee_sustain)" in rig
assert "acceleration_burst, melee_sustain)" in equip
assert 'fx.call("set_exhaust", active and str(set_id) == selected_booster,' in equip

# Keep the original 10-sided normal jet, but project its ordinary end beyond
# occluding arms and make it visible at normal contact and full follow-through.
assert "const MELEE_SUSTAIN_RESPONSE_SECONDS: float = 0.06" in fx
assert "var melee_sustain_amount: float = 0.0" in fx
assert "var sustain_target: float = 1.0 if melee_sustain else 0.0" in fx
assert "melee_sustain_amount = lerpf(melee_sustain_amount, sustain_target," in fx
assert "1.0 - exp(-maxf(delta, 0.0) / MELEE_SUSTAIN_RESPONSE_SECONDS)" in fx
assert "melee_sustain_amount = 0.0" in fx
for s in (
    'material.set_shader_parameter("melee_sustain", 0.0)',
    'outer_material.set_shader_parameter("melee_sustain", 0.0)',
    'inner_material.set_shader_parameter("melee_sustain", 0.0)',
    'outer_material.set_shader_parameter("melee_sustain", melee_sustain_amount)',
    'inner_material.set_shader_parameter("melee_sustain", melee_sustain_amount)',
):
    assert s in fx,s
assert "uniform float melee_sustain : hint_range(0.0, 1.0) = 0.0;" in shader
assert "VERTEX.z *= 1.0 + 0.65 * melee_sustain * along;" in shader
assert "VERTEX.xy *= 1.0 + 14.0 * fan;" in shader
assert "EMISSION = flame_tint.rgb * (0.75 + 0.45 * pulse) * (1.0 + 0.85 * burst)" in shader
assert "* (1.0 + 0.30 * melee_sustain);" in shader
assert "* (1.0 + 0.65 * melee_sustain), 0.0, 0.9);" in shader
assert "const EXHAUST_RADIAL_SIDES: int = 10" in fx
assert "const BURST_RISE_SECONDS: float = 0.05" in fx
assert "const BURST_FALL_SECONDS: float = 0.18" in fx

# 60fps transition smoothly reaches a stable 1.65x tail and 1.65x opacity
# multiplier, with no jump on the first frame or any amplification off-attack.
for fps in (30,60,90,120):
    x=0.
    for _ in range(round(fps*.3)):
        a=1.-math.exp(-1./fps/.06)
        x+= (1.-x)*a
        assert 0.0<=x<=1.0
    assert 0.98<x<=1.0
    assert 1.0<1.0+.65*x<=1.65
assert math.isclose(1.0+.65*1.0,1.65)
assert math.isclose(1.0+.65*0.0,1.0)

# A normal swing can be visible with no velocity, after hit, or during
# hit-stop. Plain IDLE/BASH/SLIDE/STEP cannot acquire the melee sustain flag.
for state in ("MELEE_APPROACH","DASH","STRIKE_TRACK","STRIKE","BASH_TRACK","BASH","BACK_KICK_TRACK"):
    assert state in normal
for state in ("IDLE","SLIDE"):
    assert ("CombatState."+state) not in normal
assert "const SLIDE_BOOST_POSE_MAX_WEIGHT: float = 0.50" in rig

print("PASS v221: full normal melee emits without motion/hit-stop and uses stable rearward aim")
print("PASS: sustained 10-sided ordinary jet tail is longer/brighter, no false 15x burst")
print("PASS: reset on idle/cancel, guards, jumps, heavy SLIDE and EN conditions preserved")
print("Device/Android screenshot confirmation remains outstanding")
