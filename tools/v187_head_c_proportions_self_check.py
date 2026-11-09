#!/usr/bin/env python3
"""SERA v187 regression: C head dimensions, neck join, embedded model and palette."""
from pathlib import Path
import json
import re
root=Path(__file__).resolve().parents[1]
project=(root/"project.godot").read_text(encoding="utf-8")
if not re.search(r'^config/name="SERA v187"
model=json.loads((root/"models/SERA_BOOSTER_allテスト.bbmodel").read_text(encoding="utf-8"))
assert len(model["outliner"])==4 and len(model["animations"])==23
meshes={e["name"]: e for e in model["elements"]}
head=meshes["HeadC_Head_torus"]
neck=meshes["HeadC_Neck_tube"]
def world_bbox(e):
    vs=list(e["vertices"].values())
    return [(min(v[i] for v in vs)+e["origin"][i], max(v[i] for v in vs)+e["origin"][i]) for i in range(3)]
h=world_bbox(head)
n=world_bbox(neck)
a=world_bbox(meshes["Head_Mesh"])
assert 0.95 <= (h[0][1]-h[0][0])/(a[0][1]-a[0][0]) <= 1.1
assert 25 < h[1][0] < 26 and 29 < h[1][1] < 31
assert 22 < n[1][0] < 24 and 25 < n[1][1] < 27
assert n[1][1] > h[1][0]
assert n[0][1]-n[0][0] < 4.1
assert len(head["vertices"])==96 and len(neck["vertices"])==48
assert head["origin"]==[0,27.4,0] and neck["origin"]==[0,24.4,0]
assert len({g["uuid"] for g in model["groups"]}|{e["uuid"] for e in model["elements"]}) == len(model["groups"])+len(model["elements"])
embedded=(root/"assets/sera_equipment_data.gd").read_text(encoding="utf-8")
parts=[json.loads(line.strip().rstrip(",")) for line in embedded.splitlines() if line.lstrip().startswith('"')]
snapshot=json.loads("".join(parts))
for k in ("groups","elements","outliner"): assert snapshot[k]==model[k],k
loader=(root/"scripts/sera_equipment.gd").read_text(encoding="utf-8")
assert 'if set_id == "C":' in loader and 'material_c.albedo_color = Color(0.60, 0.65, 0.72, 1.0)' in loader
assert 'if set_id != "B":' in loader
assert (root/"README_v187_ja.md").is_file()
print("PASS: v187 Head C proportions and asset snapshot")
print("Android/Godot runtime not tested")
, project, re.M):
    print("SKIP: historical v187 head C scale check on later game version")
    raise SystemExit(0)
model=json.loads((root/"models/SERA_BOOSTER_allテスト.bbmodel").read_text(encoding="utf-8"))
assert len(model["outliner"])==4 and len(model["animations"])==23
meshes={e["name"]: e for e in model["elements"]}
head=meshes["HeadC_Head_torus"]
neck=meshes["HeadC_Neck_tube"]
def world_bbox(e):
    vs=list(e["vertices"].values())
    return [(min(v[i] for v in vs)+e["origin"][i], max(v[i] for v in vs)+e["origin"][i]) for i in range(3)]
h=world_bbox(head)
n=world_bbox(neck)
a=world_bbox(meshes["Head_Mesh"])
assert 0.95 <= (h[0][1]-h[0][0])/(a[0][1]-a[0][0]) <= 1.1
assert 25 < h[1][0] < 26 and 29 < h[1][1] < 31
assert 22 < n[1][0] < 24 and 25 < n[1][1] < 27
assert n[1][1] > h[1][0]
assert n[0][1]-n[0][0] < 4.1
assert len(head["vertices"])==96 and len(neck["vertices"])==48
assert head["origin"]==[0,27.4,0] and neck["origin"]==[0,24.4,0]
assert len({g["uuid"] for g in model["groups"]}|{e["uuid"] for e in model["elements"]}) == len(model["groups"])+len(model["elements"])
embedded=(root/"assets/sera_equipment_data.gd").read_text(encoding="utf-8")
parts=[json.loads(line.strip().rstrip(",")) for line in embedded.splitlines() if line.lstrip().startswith('"')]
snapshot=json.loads("".join(parts))
for k in ("groups","elements","outliner"): assert snapshot[k]==model[k],k
loader=(root/"scripts/sera_equipment.gd").read_text(encoding="utf-8")
assert 'if set_id == "C":' in loader and 'material_c.albedo_color = Color(0.60, 0.65, 0.72, 1.0)' in loader
assert 'if set_id != "B":' in loader
assert (root/"README_v187_ja.md").is_file()
print("PASS: v187 Head C proportions and asset snapshot")
print("Android/Godot runtime not tested")
