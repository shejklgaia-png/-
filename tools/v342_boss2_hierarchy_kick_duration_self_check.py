#!/usr/bin/env python3
"""v342: Blockbench boss-test (2) clean quadruped and kick timing contract.

Checks hierarchy/animation UUID integrity; no geometry or keyframe migration.
"""
import json
import math
from collections import Counter
from sera_active_contracts import require_min_version
from pathlib import Path

root=Path(__file__).resolve().parents[1]
bb=root/"models/storage/ボステスト (2).bbmodel"
model=json.loads(bb.read_text(encoding="utf-8"))
main=(root/"scripts/main.gd").read_text(encoding="utf-8")
spec=json.loads((root/"tools/sera_active_specs.json").read_text(encoding="utf-8"))
project=(root/"project.godot").read_text(encoding="utf-8")
assert require_min_version(project, 343)
assert "const SIDE_KICK_MOTION_TIME_MULTIPLIER: float = 13.0 / 6.0" in main
assert "const SIDE_KICK_DURATION_REFERENCE_DISTANCE: float = 3.0" in main
assert "const SIDE_KICK_STEP_SPEED: float = 10.0" in main
assert "const SIDE_KICK_BOOST_DISTANCE: float = 4.0" in main
assert math.isclose(3.0/10.0*(13.0/6.0),.65,abs_tol=1e-12)
assert math.isclose(spec["side_kick"]["nominal_duration_s"],.65,abs_tol=1e-12)
assert math.isclose(spec["side_kick"]["motion_time_multiplier"],13.0/6.0,abs_tol=1e-12)

groups={g["uuid"]:g for g in model["groups"]}
meshes={e["uuid"]:e for e in model["elements"]}
expected_names={"Body","Head"}
for region in ("Front","Rear"):
    for part in ("Leg","LowerLeg","Foot"):
        expected_names.update({region+part+"_R",region+part+"_L"})
assert len(groups)==len(expected_names)==14
assert {g["name"] for g in groups.values()}==expected_names
assert len(meshes)==14
assert len(model["outliner"])==1
assert groups[model["outliner"][0]["uuid"]]["name"]=="Body"
assert all("Body2" not in g["name"] and not g["name"].endswith("2")
           for g in groups.values())

visited_groups=[]
visited_meshes=[]
parents={}
def walk(nodes,parent=None):
    for node in nodes:
        if isinstance(node,str):
            assert node in meshes and node not in visited_meshes
            visited_meshes.append(node)
            parents[node]=parent
        else:
            uid=node["uuid"]
            assert uid in groups and uid not in visited_groups
            visited_groups.append(uid)
            parents[uid]=parent
            walk(node["children"],uid)
walk(model["outliner"])
assert set(visited_groups)==set(groups)
assert set(visited_meshes)==set(meshes)
by_name={g["name"]:g for g in groups.values()}
def idof(name):
    return by_name[name]["uuid"]

body=idof("Body")
assert any(meshes[uid]["name"]=="body_mesh" and parents[uid]==body
           for uid in meshes)
head=idof("Head")
assert parents[head]==body
assert any(meshes[uid]["name"]=="head_mesh" and parents[uid]==head
           for uid in meshes)
for region in ("Front","Rear"):
    for side in ("R","L"):
        upper=region+"Leg_"+side
        lower=region+"LowerLeg_"+side
        foot=region+"Foot_"+side
        assert parents[idof(upper)]==body
        assert parents[idof(lower)]==idof(upper)
        assert parents[idof(foot)]==idof(lower)
        for folder in (upper,lower,foot):
            mesh_name=folder+"_Mesh"
            assert sum(meshes[uid]["name"]==mesh_name
                       and parents[uid]==idof(folder) for uid in meshes)==1
    for part in ("Leg","LowerLeg","Foot"):
        right=by_name[region+part+"_R"]["origin"]
        left=by_name[region+part+"_L"]["origin"]
        assert right[0]>0 and left[0]<0
        assert math.isclose(right[0],-left[0],abs_tol=1e-5)
        assert math.isclose(right[1],left[1],abs_tol=1e-5)
        assert math.isclose(right[2],left[2],abs_tol=1e-5)

# The source Wait animation keeps its 10 existing UUID-keyed tracks and
# every original keyframe; group renaming must also update animator labels.
animations=model["animations"]
assert len(animations)==1 and animations[0]["name"]=="Wait"
anim=animations[0]["animators"]
assert len(anim)==10
for uuid,track in anim.items():
    assert uuid in groups
    assert track["name"]==groups[uuid]["name"]
    assert len(track["keyframes"])>=1

# No duplicate mesh/cube references; new paired foot folders still keep
# Blockbench mesh-level mirror-editing support.
for mesh in meshes.values():
    assert mesh["type"]=="mesh"
    assert mesh["allow_mirror_modeling"] is True
    assert mesh.get("vertices") and mesh.get("faces")

print("PASS v342 boss-test (2) single Body root, 14 meshes, 14 groups, 6 mirrored L/R pairs, Wait refs, 0.65s kicks")
