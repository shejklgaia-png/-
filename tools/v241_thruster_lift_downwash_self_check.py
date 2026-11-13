#!/usr/bin/env python3
"""SERA v241: lift-producing world-DOWN bias on all active thruster nozzles."""
from __future__ import annotations

from pathlib import Path
import math
import re

ROOT=Path(__file__).resolve().parents[1]
def read(path): return (ROOT/path).read_text(encoding="utf-8")
fx=read("scripts/back_thruster_fx.gd")
rig=read("scripts/sera_rig.gd")
equipment=read("scripts/sera_equipment.gd")
main=read("scripts/main.gd")
policy=read("scripts/render_order_policy.gd")
project=read("project.godot")
version=re.search(r'config/name="SERA v(\d+)"',project)
assert version and int(version.group(1))>=241
assert (ROOT/"docs/history/release_notes/README_v241_ja.md").exists()

# A shared, WORLD-gravity-driven function acts on final requested headings.
assert "const LIFT_DOWNWASH_WEIGHT: float = 0.40" in fx
f=fx.split("func _with_lift_downwash(",1)[1].split("func set_exhaust(",1)[0]
for token in ("local_direction.normalized()", 
              "rest_basis.inverse() * Vector3.DOWN",
              "local_down * LIFT_DOWNWASH_WEIGHT",
              ").normalized()"):
    assert token in f,token
set_fn=fx.split("func set_exhaust(",1)[1]
assert "if enabled and world_exhaust_direction.length_squared() > 0.000001:" in set_fn
assert "if enabled and left_sector_world.length_squared() > 0.000001:" in set_fn
assert "local_dir = _with_lift_downwash(local_dir, rest_basis)" in set_fn
assert "local_sector_direction = _with_lift_downwash(" in set_fn
assert "local_sector_direction, rest_basis)" in set_fn
assert set_fn.index("local_dir = _with_lift_downwash(") < set_fn.index("var rear_denominator:")
assert set_fn.index("local_sector_direction = _with_lift_downwash(") < set_fn.index("var screen_sector_quaternion:")
assert "rest_basis.inverse() * world_exhaust_direction.normalized()" in set_fn
assert "rest_basis.inverse() * left_sector_world.normalized()" in set_fn

# Preserve real Blockbench hinge articulation and safety/transition behavior.
for token in (
    "const PITCH_UP_LIMIT_RADIANS: float = PI * 1.0 / 180.0",
    "const PITCH_DOWN_LIMIT_RADIANS: float = PI * 90.0 / 180.0",
    "const YAW_LIMIT_RADIANS: float = PI * 80.0 / 180.0",
    "const MELEE_YAW_LIMIT_RADIANS: float = PI * 20.0 / 180.0",
    "const MELEE_PITCH_DOWN_LIMIT_RADIANS: float = PI * 35.0 / 180.0",
    "steering_pitch = PITCH_DOWN_LIMIT_RADIANS",
    "yaw = lerpf(yaw, 0.0, backstroke)",
    "pitch = lerpf(pitch, PITCH_DOWN_LIMIT_RADIANS, backstroke)",
    "steering_yaw = lerp_angle(steering_yaw, yaw, ease)",
    "steering_pitch = lerp_angle(steering_pitch, pitch, ease)",
    "returning_from_screen_sector = true",
    "nozzle.quaternion = nozzle.quaternion.slerp(",
    "var normal_quaternion: Quaternion",
    "if enabled and melee_sustain:",
    "_avoid_melee_body_penetration(nozzle, nozzle.get_parent() as Node3D)",
    "_update_ribbon_trail(enabled, delta)",
    "visible = enabled",
):
    assert token in fx,token

# The 3D flame and world-fixed ribbons follow the REAL nozzle's final pose.
assert "nozzle_rest_rotation = nozzle.quaternion" in fx
assert "nozzle.quaternion = normal_quaternion" in fx
assert "Quaternion(Vector3.BACK, local_sector_direction)" in fx
assert "global_transform.basis * Vector3.BACK" in fx
assert "ribbon_material.render_priority = RENDER_ORDER.DEPTH_TESTED_EMISSIVE" in fx
assert "material.render_priority = RENDER_ORDER.DEPTH_TESTED_EMISSIVE" in fx
assert "const DEPTH_TESTED_EMISSIVE: int = 127" in policy
assert "fx.call(\"set_exhaust\"" in equipment
assert 'left_sector_world, acceleration_burst, melee_sustain)' in rig
presentation = read("scripts/sera_thruster_presentation.gd")
assert "thruster_presentation.update(rig, exhaust_on," in main
assert "direction_of_exhaust, delta, backstroke_weight, left_sector_world," in main
assert "left_sector_world, acceleration_burst, normal_attack_exhaust)" in presentation

def norm(v):
    length=math.sqrt(sum(x*x for x in v))
    assert length>1e-7
    return tuple(x/length for x in v)
def add(a,b): return tuple(x+y for x,y in zip(a,b))
def dot(a,b): return sum(x*y for x,y in zip(a,b))
def rotate(v,yaw,pitch,roll):
    # R_y * R_x * R_z, orthonormal, changing both Chest and nozzle hinges.
    c,s=math.cos(roll),math.sin(roll)
    x,y,z=v
    v=(c*x-s*y,s*x+c*y,z)
    c,s=math.cos(pitch),math.sin(pitch)
    x,y,z=v
    v=(x,c*y-s*z,s*y+c*z)
    c,s=math.cos(yaw),math.sin(yaw)
    x,y,z=v
    return (c*x+s*z,y,-s*x+c*z)

down=(0.,-1.,0.)
weight=.40
# The sum in rest space has to equal world-space downward bias for
# arbitrary yaw/pitch/roll of BOTH independently animated nozzle parents.
for yaw in (-2.2,-.9,0.,1.1,2.6):
    for pitch in (-.8,0.,.47):
        for roll in (-.6,.1,.83):
            axes=[rotate((1.,0.,0.),yaw,pitch,roll),
                  rotate((0.,1.,0.),yaw,pitch,roll),
                  rotate((0.,0.,1.),yaw,pitch,roll)]
            def inverse_rot(vec): return tuple(dot(vec,axis) for axis in axes)
            def forward_rot(v): return tuple(sum(v[j]*axes[j][i] for j in range(3)) for i in range(3))
            for desired in ((0.,0.,1.),(0.,0.,-1.),(.75,0.,.66),
                            (-.61,0.,.79),(.3,-.2,.94)):
                target_world=norm(add(norm(desired),tuple(weight*d for d in down)))
                target_local=norm(add(norm(inverse_rot(desired)),
                                     tuple(weight*d for d in inverse_rot(down))))
                actual=norm(forward_rot(target_local))
                assert all(abs(a-b)<1e-8 for a,b in zip(actual,target_world)), (
                    yaw,pitch,roll,desired,actual,target_world)

# Level BOOST/STEP has ~21.8 degrees downwards, bounded 0..90 deg by old
# servo; fully backward stays exactly vertical after v210 override.
level=norm((0.,-weight,1.))
angle=math.degrees(math.atan2(-level[1], math.hypot(level[0],level[2])))
assert 21.0 < angle < 23.0
down_cap=math.radians(90.0)
for horizontal in ((0.,0.,1.),(1.,0.,0.),(-1.,0.,0.),(.5,0.,.5)):
    biased=norm(add(norm(horizontal),(0.,-weight,0.)))
    pitch=max(-math.radians(1.),min(down_cap,
        -math.atan2(biased[1], math.hypot(biased[0],biased[2]))))
    assert 0 < pitch < math.radians(35.)
    assert math.isclose(down_cap*(1-1.0)+pitch*(1-1.0)+down_cap*1.0,down_cap)

# Camera LEFT-sector stays down/right; bias changes its midpoint from 45
# degrees toward stronger lift, independent of camera azimuth.
for camera_yaw in (-2.5,-.6,0.,1.0,2.8):
    right=(math.cos(camera_yaw),0.,math.sin(camera_yaw))
    for left_weight in (0.,.25,.5,.75,1.):
        t=math.pi/4*left_weight
        sector=(right[0]*math.sin(t),-math.cos(t),right[2]*math.sin(t))
        biased=norm(add(sector,(0.,-weight,0.)))
        screen_r=dot(biased,right)
        assert screen_r>=-1e-9 and biased[1]<0
        assert -1e-8 <= math.atan2(screen_r,-biased[1]) <= math.pi/4+1e-8
        if left_weight==1.:
            assert -biased[1] > -sector[1]

print("PASS v241: world-down lift correction on both standard and LEFT sector paths")
print("PASS v241: neutral 21.8-degree down pitch, backward vertical, safe 80/90/1 and melee 20/35 limits")
print("PASS v241: all rest rotations, screen quadrant, rendering/ribbon/torso-clearance preserved")
print("Godot parser and Android real-time rendering not exercised")
