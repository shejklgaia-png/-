#!/usr/bin/env python3
"""v188: Verify Head C scaled 1.5x versus v187, with stable A rig and asset snapshot."""
from pathlib import Path
import json, re
root=Path(__file__).resolve().parents[1]
project=(root/"project.godot").read_text(encoding="utf-8")
if not re.search(r'^config/name="SERA v188"$',project,re.M):
    print("SKIP: v188-specific Head C scale test"); raise SystemExit(0)
model=json.loads((root/"models/SERA_BOOSTER_allテスト.bbmodel").read_text(encoding="utf-8"))
assert len(model["groups"])==48 and len(model["elements"])==51 and len(model["animations"])==23
meshes={m["name"]:m for m in model["elements"]}
head=meshes["HeadC_Head_torus"]
neck=meshes["HeadC_Neck_tube"]
def widths(mesh):
    pts=list(mesh["vertices"].values())
    return [max(p[i] for p in pts)-min(p[i] for p in pts) for i in range(3)]
assert abs(widths(head)[0]-9.6)<0.0001
assert abs(widths(neck)[0]-5.952)<0.0001
assert head["origin"] == [0,27.4,0]
assert neck["origin"] == [0,24.4,0]
assert head["rotation"]==[0,0,0] and neck["rotation"]==[0,0,0]
assert len(head["vertices"])==96 and len(neck["vertices"])==48
assert len(set(g["uuid"] for g in model["groups"])|set(e["uuid"] for e in model["elements"]))==len(model["groups"])+len(model["elements"])
embedded=(root/"assets/sera_equipment_data.gd").read_text(encoding="utf-8")
segments=[json.loads(line.strip().rstrip(",")) for line in embedded.splitlines() if line.lstrip().startswith('"')]
snapshot=json.loads("".join(segments))
for k in ("groups","elements","outliner"): assert snapshot[k]==model[k]
loader=(root/"scripts/sera_equipment.gd").read_text(encoding="utf-8")
assert 'if set_id == "C":' in loader
assert 'material_c.albedo_color = Color(0.60, 0.65, 0.72, 1.0)' in loader
print("PASS: v188 Head C 1.5x and embedded data; Godot Android runtime not tested")
