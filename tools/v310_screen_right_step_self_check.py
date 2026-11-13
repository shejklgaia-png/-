#!/usr/bin/env python3
"""v310: screen-right STEP always selects Step_R and preserves its 9.2.2 yaw."""
import json, math, re
from pathlib import Path
R = Path(__file__).resolve().parents[1]
def read(p): return (R/p).read_text(encoding="utf-8")
main=read("scripts/main.gd")
rig=read("scripts/sera_rig.gd")
assert int(re.search(r'config/name="SERA v(\d+)"',read("project.godot")).group(1))>=310
source=json.loads(read("models/storage/SERA_BOOSTER_allテスト (9) (2) (2).bbmodel"))
live=json.loads(read("assets/sera_source.json"))
original=next(a for a in source["animations"] if a["name"]=="Step_R")
now=next(a for a in live["animations"] if a["name"]=="Step_R")
assert now==original,"the user's 9.2.2 Step_R must not be modified"
start=main.split("func _start_omni_step(flick: Vector2) -> bool:",1)[1].split("func _start_back_step()",1)[0]
assert "var direction: Vector2 = flick.normalized()" in start
assert "var world_step: Vector3 = _screen_drag_to_ground(direction)" in start
version=int(re.search(r'config/name="SERA v(\d+)"',read("project.godot")).group(1))
if version == 310:
    assert "var pose_direction: Vector2 = direction" in start
else:
    assert "var pose_direction: Vector2 = _step_motion_direction(world_step, direction)" in start
assert "_step_local_pose_direction(world_step)" not in start
assert 'rig.call("start_omni_step", pose_direction)' in start
assert "step_linear_offset = Vector2(world_step.x, world_step.z)" in start
assert "step_arc_length = _step_fixed_distance_for_direction(direction)" in start
phy=main.split("func _physics_process(delta: float) -> void:",1)[1].split("func _process(delta: float) -> void:",1)[0]
if version == 310:
    assert 'rig.call("update_omni_step_direction", step_flick_this_frame, delta)' in phy
else:
    assert 'rig.call("update_omni_step_direction", _step_motion_direction(' in phy
assert "_step_local_pose_direction(committed_world_step)" not in phy
pose=rig.split("func _step_right_authored_yaw_weight() -> float:",1)[1].split("func start_omni_step(",1)[0]
for tok in ("step_playback","directional_step_active","directional_step_vector.x <= 0.0",
            "atan2(absf(direction.x), absf(direction.y)) / (PI * 0.5)",
            "return angle * angle * (3.0 - 2.0 * angle)"):
    assert tok in pose,tok
anim=rig.split("func _apply_animation(_delta: float) -> void:",1)[1].split("func _blockbench_rotation(",1)[0]
assert "facing_weight *= 1.0 - _step_right_authored_yaw_weight()" in anim
assert "q = _face_locked_boss_with_waist(q, facing_weight)" in anim
assert "if blend_weight < 1.0 and prior_rotations.has(uid):" in anim
assert anim.index("prior_rotations.has(uid)") < anim.index("_face_locked_boss_with_waist(q, facing_weight)")
def weight(x,y):
    if x<=0:return 0.
    a=math.atan2(abs(x),abs(y))/(math.pi*.5)
    return a*a*(3-2*a)
assert abs(weight(1,0)-1)<1e-10
assert abs(weight(0,-1))<1e-10
assert abs(weight(-1,0))<1e-10
for xy in [(1,-1),(1,1)]:
    assert abs(weight(*xy)-.5)<1e-10
previous=weight(math.sin(0),-math.cos(0))
for i in range(1,1441):
    ang=math.radians(i*.25)
    v=weight(math.sin(ang),-math.cos(ang))
    assert abs(v-previous)<.01
    previous=v
print("PASS v310: screen-relative 4-way pose and unchanged world travel; original right yaw retained")
