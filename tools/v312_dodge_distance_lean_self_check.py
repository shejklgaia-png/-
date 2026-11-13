#!/usr/bin/env python3
"""v312: every screen dodge is 7m/15m/s, with additive directional crouch."""
from pathlib import Path
import math, re, json, base64
ROOT=Path(__file__).resolve().parents[1]
def read(p):return (ROOT/p).read_text(encoding="utf-8")
m=read("scripts/main.gd"); r=read("scripts/sera_rig.gd")
version=int(re.search(r'config/name="SERA v(\d+)"',read("project.godot")).group(1))
assert version>=312
def constant(text,name):
    x=re.search(r'^const '+re.escape(name)+r': float = ([0-9.]+)',text,re.M)
    assert x,name
    return float(x.group(1))
for name in ("STEP_SIDE_DISTANCE","STEP_FORWARD_DISTANCE","BACK_STEP_DISTANCE",
             "STEP_MIN_ARC_LENGTH","STEP_MAX_ARC_LENGTH"):
    assert constant(m,name)==7.0,name
assert constant(m,"STEP_SPEED")==15.0
assert constant(m,"SIDE_KICK_STEP_SPEED")==10.0
assert constant(m,"SIDE_KICK_BOOST_DISTANCE")==3.0
assert math.isclose(7.0/15.0,0.4666666666666667)
distance=m.split("func _step_fixed_distance_for_direction(_direction: Vector2) -> float:",1)[1].split(
    "func _start_omni_step(",1)[0]
assert "return STEP_SIDE_DISTANCE" in distance
assert "lerpf(" not in distance and "smoothstep(" not in distance
start=m.split("func _start_omni_step(flick: Vector2) -> bool:",1)[1].split(
    "func _start_back_step()",1)[0]
for token in ('step_arc_length = _step_fixed_distance_for_direction(direction)',
              'step_speed_current = STEP_SPEED * float(part_stats.get("step_speed_mult", 1.0))',
              'step_duration_current = (step_arc_length / step_speed_current',
              'var world_step: Vector3 = _screen_drag_to_ground(direction)',
              'var pose_direction: Vector2 = _step_motion_direction(world_step, direction)',
              'step_linear_offset = Vector2(world_step.x, world_step.z)',
              'step_speed_current = SIDE_KICK_STEP_SPEED * float(',
              'step_arc_length = SIDE_KICK_BOOST_DISTANCE',
              'SIDE_KICK_MOTION_TIME_MULTIPLIER',
              'rig.call("start_omni_step", pose_direction)'):
    assert token in start,token
for name in ("_start_back_step() -> bool:","_start_side_step(side: int) -> bool:"):
    assert name in m
assert constant(r,"STEP_DODGE_LEAN_DEGREES")==22.0
assert constant(r,"STEP_DODGE_LOWER_METERS")==0.14
lean=r.split("func _step_dodge_lean_rotation(blend_weight: float) -> Quaternion:",1)[1].split(
    "func start_omni_step(",1)[0]
for token in ("step_playback","directional_step_active",
              "directional_step_vector.normalized()",
              "Vector3(motion.y, 0.0, -motion.x).normalized()",
              "STEP_DODGE_LEAN_DEGREES","clampf(blend_weight, 0.0, 1.0)"):
    assert token in lean,token
animation=r.split("func _apply_animation(_delta: float) -> void:",1)[1].split(
    "func _blockbench_rotation(",1)[0]
assert "if uid == RUN_ROOT_BONE_UUID and step_playback and directional_step_active:" in animation
assert "q = (_step_dodge_lean_rotation(blend_weight) * q).normalized()" in animation
assert "translation.y -= STEP_DODGE_LOWER_METERS * blend_weight" in animation
assert animation.index("q = _face_locked_boss_with_waist(q, facing_weight)") < animation.index(
    "q = (_step_dodge_lean_rotation(blend_weight) * q).normalized()")
assert animation.index("if blend_weight < 1.0 and prior_rotations.has(uid):") < animation.index(
    "q = (_step_dodge_lean_rotation(blend_weight) * q).normalized()")
assert "step_playback = true\n    directional_step_active = false" in r
# No user-authored Blockbench keyframes or generated JSON were edited.
auth=json.loads(read("models/storage/SERA_BOOSTER_allテスト (9) (2) (2).bbmodel"))
source=json.loads(read("assets/sera_source.json"))
clip=lambda d:next(x for x in d["animations"] if x["name"]=="Step_R")
assert clip(auth)==clip(source)
parts=re.findall(r'^    "([A-Za-z0-9+/=]+)",$',read("assets/sera_data.gd"),re.M)
assert base64.b64decode("".join(parts))==(ROOT/"assets/sera_source.json").read_bytes()
# Directional lean axis points local UP toward the travel direction.
for x,y in ((0,-1),(1,0),(0,1),(-1,0),
            (2**-.5,-2**-.5),(-2**-.5,2**-.5)):
    axis=(y,0.,-x)
    assert math.isclose(math.hypot(axis[0],axis[2]),1,abs_tol=1e-10)
    tilted_horizontal=(-axis[2],axis[0])
    assert math.isclose(tilted_horizontal[0]*x+tilted_horizontal[1]*y,1.,abs_tol=1e-10)
print("V312_DODGE_7M_15MPS_LOW_DIRECTIONAL_LEAN_STATIC_PASS")
