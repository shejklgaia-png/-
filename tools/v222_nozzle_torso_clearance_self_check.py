#!/usr/bin/env python3
"""SERA v222: melee nozzles never aim back through the animated torso."""
from __future__ import annotations
import json
import math
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

fx=read("scripts/back_thruster_fx.gd")
equip=read("scripts/sera_equipment.gd")
main=read("scripts/main.gd")
rig=read("scripts/sera_rig.gd")
project=read("project.godot")
m=re.search(r'config/name="SERA v(\d+)"',project)
assert m and int(m.group(1))>=222

# All animations change the WORLD Chest basis every frame. Using static player
# yaw as the sole steering reference previously let the jet turn into SERA.
assert "const MELEE_TORSO_CLEARANCE_DOT: float = 0.55" in fx
method=fx.split(
    "func _avoid_melee_body_penetration(nozzle: Node3D, nozzle_parent: Node3D) -> void:",1)[1].split(
    "func set_exhaust(",1)[0]
for token in (
    "var chest: Node3D = nozzle_parent.get_parent() as Node3D",
    "nozzle.global_position - chest.global_position",
    "nozzle.global_transform.basis * Vector3.BACK",
    "var outward_dot: float = jet_axis.dot(outward)",
    "if outward_dot >= MELEE_TORSO_CLEARANCE_DOT:",
    "var tangent: Vector3 = jet_axis - outward * outward_dot",
    "if tangent.length_squared() > 0.000001:",
    "tangent.normalized() * sqrt(",
    "1.0 - MELEE_TORSO_CLEARANCE_DOT * MELEE_TORSO_CLEARANCE_DOT",
    "nozzle_parent.global_transform.basis",
    "* Basis(nozzle_rest_rotation)).orthonormalized()",
    "rest_basis.inverse() * safe_axis",
    "Quaternion(Vector3.BACK, local_safe)",
):
    assert token in method,token
assert "if enabled and melee_sustain:\n        _avoid_melee_body_penetration(nozzle, nozzle.get_parent() as Node3D)" in fx
assert fx.rindex('if enabled and melee_sustain:') > fx.index('else:\n        nozzle.quaternion = normal_quaternion')
assert fx.rindex('if enabled and melee_sustain:') < fx.index('visible = enabled')
assert "nozzle_rest_rotation = nozzle.quaternion" in fx
assert "melee_sustain: bool = false" in fx
assert "left_sector_world, acceleration_burst, normal_melee_exhaust)" in main
assert "left_sector_world, acceleration_burst, melee_sustain)" in rig
assert "acceleration_burst, melee_sustain)" in equip

# v224 also introduces an earlier melee articulation clamp; rindex() above
# intentionally checks the later torso-clearance guard.
# Safety applied only to active normal melee. All original BOOST/STEP/left
# camera quadrant/nozzle pitch steering still has its own existing logic.
assert "if enabled and world_exhaust_direction.length_squared() > 0.000001:" in fx
assert "if enabled and left_sector_world.length_squared() > 0.000001:" in fx
assert 'const YAW_LIMIT_RADIANS: float = PI * 80.0 / 180.0' in fx
assert 'const PITCH_DOWN_LIMIT_RADIANS: float = PI * 90.0 / 180.0' in fx
assert 'const EXHAUST_RADIAL_SIDES: int = 10' in fx
assert 'const BURST_RISE_SECONDS: float = 0.05' in fx
assert 'const BURST_FALL_SECONDS: float = 0.18' in fx
assert 'const SLIDE_BOOST_POSE_MAX_WEIGHT: float = 0.50' in rig

# Verify the correct authored Chest -> BOOSTER -> Thruster_L/R hierarchy.
# Both pivots are behind/below/outside Chest and permit a safe local outward
# hemisphere, even though the entire Chest pitches and rolls during combos.
model=json.loads(read("models/SERA_BOOSTER_allテスト.bbmodel"))
groups={g["name"]:g for g in model["groups"]}
assert groups["Chest"]["origin"] == [0,20,0]
assert groups["BOOSTER"]["origin"] == [0,20,4]
assert groups["Thruster_L"]["origin"][0] < 0
assert groups["Thruster_R"]["origin"][0] > 0

def norm(x):
    n=math.sqrt(sum(a*a for a in x))
    return tuple(a/n for a in x)

def dot(a,b): return sum(x*y for x,y in zip(a,b))

def project_safe(axis,outward,minimum=.55):
    axis=norm(axis);outward=norm(outward)
    cosine=dot(axis,outward)
    if cosine>=minimum: return axis
    tangent=tuple(axis[i]-outward[i]*cosine for i in range(3))
    mag=math.sqrt(dot(tangent,tangent))
    if mag<1e-6: return outward
    tangent=tuple(a/mag for a in tangent)
    return norm(tuple(minimum*outward[i]+math.sqrt(1.-minimum**2)*tangent[i]
                      for i in range(3)))

def rotate(v,yaw,pitch,roll):
    # arbitrary orientation changes rotate the entire authored Chest
    c,s=math.cos(yaw),math.sin(yaw)
    x,y,z=v
    v=(c*x+s*z,y,-s*x+c*z)
    c,s=math.cos(pitch),math.sin(pitch)
    x,y,z=v
    v=(x,c*y-s*z,s*y+c*z)
    c,s=math.cos(roll),math.sin(roll)
    x,y,z=v
    return (c*x-s*y,s*x+c*y,z)

chest=groups["Chest"]["origin"]
for side in ("L","R"):
    origin=groups["Thruster_"+side]["origin"]
    outward=norm(tuple(origin[i]-chest[i] for i in range(3)))
    assert outward[2] > 0.6
    for yaw in [-2.0,-1.0,0,0.8,2.4]:
        for pitch in [-1.1,0,0.7]:
            for roll in [-0.8,0,1.3]:
                o=rotate(outward,yaw,pitch,roll)
                # Representative jet directions during a complete 3-swing
                # animation (inward, down, side, backward and arbitrary).
                for desired in ((0,0,-1),(0,-1,0),(1,0,0),(-1,0,0),
                                (0,0,1),(-.4,-.6,-.7),(.2,.8,.4)):
                    x=project_safe(desired,o)
                    assert dot(x,o) >= .55-1e-9,(side,yaw,pitch,roll,desired)
                    assert math.isclose(dot(x,x),1,abs_tol=1e-10)
                    if dot(norm(desired),o)>=.55:
                        assert max(abs(x[i]-norm(desired)[i]) for i in range(3))<1e-8

# A perfectly inward jet must be redirected, never permitted to point
# through Chest. Exact side trajectories are projected onto the safety cone.
for side in ("L","R"):
    origin=groups["Thruster_"+side]["origin"]
    radial=norm(tuple(origin[i]-chest[i] for i in range(3)))
    inward=tuple(-x for x in radial)
    result=project_safe(inward,radial)
    assert math.isclose(dot(result,radial),1,abs_tol=1e-10)
    for axis in ((1,0,0),(-1,0,0),(0,1,0),(0,-1,0),(0,0,1)):
        result=project_safe(axis,radial)
        assert dot(result,radial)>=.55-1e-10

print("PASS v222: independently guarded L/R nozzle aim clears animated torso")
print("PASS: safe outward cone during arbitrary Chest yaw/pitch/roll")
print("PASS: v221 continuous 10-gon jet, v219 15x/50ms burst and other inputs intact")
print("Godot Android actual 3D nozzle clearance remains unverified")
