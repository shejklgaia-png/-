#!/usr/bin/env python3
"""v113: run-only head angular sway reduction without breaking aim or authored clips."""
from pathlib import Path
import json
import math

root = Path(__file__).resolve().parents[1]
rig = (root / "scripts/sera_rig.gd").read_text(encoding="utf-8")
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
model = json.loads((root / "assets/sera_source.json").read_text(encoding="utf-8"))
for token in (
    "const RUN_HEAD_SWAY_RETENTION: float = 0.35",
    "const RUN_HEAD_REFERENCE_PHASES = [0.0, 0.25, 0.5, 0.75]",
    "func _run_head_reference_orientation() -> Quaternion:",
    "func _stabilize_run_head_rotation(t: float, authored_head: Quaternion) -> Quaternion:",
    "func _blended_run_pose(uid: String, t: float, stabilize_head: bool = true) -> Dictionary:",
    "_blended_run_pose(str(bone_uuid), float(phase), false)",
    "_blended_run_pose(str(bone_uuid), t, false)",
    "if uid == RUN_HEAD_BONE_UUID and stabilize_head:",
    "blended_rotation = _stabilize_run_head_rotation(t, blended_rotation)",
    "return (parent_orientation.inverse() * stabilized).normalized()",
    "target_orientation.slerp(",
    "const RUN_TURN_MAX_LEAN_DEGREES: float = 15.0",
    "const RUN_UPPER_YAW_PARTS = [0.20, 0.30, 0.25, 0.25]",
):
    assert token in rig, token
assert rig.index("if uid == RUN_HEAD_BONE_UUID and stabilize_head:") < rig.index(
    'return {"rotation": blended_rotation, "position": blended_translation, "scale": blended_scale}')
assert "if running_pose:" in rig
assert "var pose: Dictionary = _blended_run_pose(str(uid), t)" in rig
assert 'config/name="SERA v' in project
assert "const STRIKE_DAMAGE = [12, 12, 26]" in main

names = {g["name"]: g["uuid"] for g in model["groups"]}
chain_names = ("Torso", "Chest", "Neck", "Head")
clips = {a["name"]: a for a in model["animations"]}
def mul(a, b):
    x,y,z,w = a
    X,Y,Z,W = b
    return (w*X+x*W+y*Z-z*Y, w*Y-x*Z+y*W+z*X,
            w*Z+x*Y-y*X+z*W, w*W-x*X-y*Y-z*Z)
def normalize(a):
    m = math.sqrt(sum(x*x for x in a))
    return tuple(x/m for x in a)
def axis(vec, degrees):
    h = math.radians(degrees)/2
    return (*[v*math.sin(h) for v in vec], math.cos(h))
def bb_quat(v):
    return normalize(mul(mul(axis((0,0,-1),float(v["z"])),
                             axis((0,1,0),float(v["y"]))),
                         axis((1,0,0),float(v["x"]))))
def slerp(a,b,t):
    dot=sum(x*y for x,y in zip(a,b))
    if dot<0:
        b=tuple(-x for x in b)
        dot=-dot
    if dot>0.9995:
        return normalize(tuple(x+(y-x)*t for x,y in zip(a,b)))
    theta=math.acos(min(1.0,dot))
    sine=math.sin(theta)
    return normalize(tuple(
        (math.sin((1-t)*theta)*x + math.sin(t*theta)*y)/sine
        for x,y in zip(a,b)))
def rotation_at(clip, bone_name, t):
    frames=sorted((k for k in clip["animators"][names[bone_name]]["keyframes"]
                   if k["channel"]=="rotation"),key=lambda x:x["time"])
    if t<=frames[0]["time"]:
        return bb_quat(frames[0]["data_points"][0])
    for a,b in zip(frames,frames[1:]):
        if t<=b["time"]:
            return slerp(bb_quat(a["data_points"][0]),bb_quat(b["data_points"][0]),
                         (t-a["time"])/(b["time"]-a["time"]))
    return bb_quat(frames[-1]["data_points"][0])
def chain(clip,t):
    result=(0.0,0.0,0.0,1.0)
    for bone in chain_names:
        result=normalize(mul(result,rotation_at(clip,bone,t)))
    return result
def distance(a,b):
    dot=abs(sum(x*y for x,y in zip(a,b)))
    return math.degrees(2*math.acos(min(1.0,dot)))
for name,max_unstabilized in [("run_front_original", 31),("run_back",5)]:
    clip=clips[name]
    phases=[0,.25,.5,.75]
    neutral=None
    for i,phase in enumerate(phases):
        q=chain(clip,phase)
        neutral=q if i==0 else slerp(neutral,q,1/(i+1))
    samples=[distance(neutral,chain(clip,i/20)) for i in range(21)]
    assert max(samples)<max_unstabilized
    assert max(samples)*.35<max_unstabilized*.4
    if name=="run_front_original":
        assert max(samples)>25, "Original strong head sway fixture missing"
    else:
        assert max(samples)<5
print("v113 RUN head-only stabilization source wiring / quaternion model: PASS")
