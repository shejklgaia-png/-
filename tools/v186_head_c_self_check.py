#!/usr/bin/env python3
"""v186: Head C is a two-mesh, third-set standard-rig head-only option."""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
project = (ROOT / "project.godot").read_text(encoding="utf-8")
if not re.search(r'^config/name="SERA v186"
model = json.loads((ROOT / "models/SERA_BOOSTER_allテスト.bbmodel").read_text(encoding="utf-8"))
source = json.loads((ROOT / "models/storage/頭C (2).bbmodel").read_text(encoding="utf-8"))
groups = {g["uuid"]: g for g in model["groups"]}
meshes = {e["uuid"]: e for e in model["elements"]}
assert len(model["outliner"]) == 4  # A, B, Swordeffect, C
assert len(model["animations"]) == 23
assert len(model["groups"]) == 48 and len(model["elements"]) == 51
assert len(set(groups) | set(meshes)) == len(groups) + len(meshes)
assert len(source["groups"]) == 2 and len(source["elements"]) == 2
assert {g["name"] for g in source["groups"]} == {"頭", "首"}
root = model["outliner"][-1]
paths = {}
def walk(node, ancestor=()):
    group = groups[node["uuid"]]
    parents = ancestor + (group["name"],)
    for c in node["children"]:
        if isinstance(c, dict):
            walk(c, parents)
        else:
            paths[meshes[c]["name"]] = parents
walk(root)
assert paths == {
    "HeadC_Neck_tube": ("Waist3","Torso3","Chest3","Neck3"),
    "HeadC_Head_torus": ("Waist3","Torso3","Chest3","Neck3","Head3"),
}
assert groups[root["uuid"]]["origin"] == [0, 17, 0]
assert next(g["origin"] for g in groups.values() if g["name"] == "Neck3") == [0, 23, 0]
assert next(g["origin"] for g in groups.values() if g["name"] == "Head3") == [0, 25, 0]
assert meshes[next(k for k,v in meshes.items() if v["name"] == "HeadC_Neck_tube")]["origin"] == [0, 12.1, -0.8]
assert meshes[next(k for k,v in meshes.items() if v["name"] == "HeadC_Head_torus")]["origin"] == [0, 20.7, 3.3]
assert all(meshes[k]["rotation"] == [0,0,0] for k in meshes if meshes[k]["name"].startswith("HeadC_"))
for m in model["elements"]:
    if m["name"].startswith("HeadC_"):
        assert len(m["vertices"]) > 0 and len(m["faces"]) > 0
embedded = (ROOT / "assets/sera_equipment_data.gd").read_text(encoding="utf-8")
parts = [json.loads(line.strip().rstrip(",")) for line in embedded.splitlines()
         if line.lstrip().startswith('"')]
snapshot = json.loads("".join(parts))
for name in ("groups","elements","outliner"):
    assert snapshot[name] == model[name]
loader = (ROOT / "scripts/sera_equipment.gd").read_text(encoding="utf-8")
assert "func options_for(slot: String)" in loader
assert "var letter: String = String.chr(65 + index)" in loader
assert 'return "head"' in loader
assert (ROOT / "README_v186_ja.md").is_file()
print("PASS: Head C attached to standard Neck/Head, head-only C, embedded snapshot matches")
print("Godot/Android runtime NOT TESTED")
, project, re.M):
    print("SKIP: historical v186 head C layout check")
    raise SystemExit(0)
model = json.loads((ROOT / "models/SERA_BOOSTER_allテスト.bbmodel").read_text(encoding="utf-8"))
source = json.loads((ROOT / "models/storage/頭C (2).bbmodel").read_text(encoding="utf-8"))
groups = {g["uuid"]: g for g in model["groups"]}
meshes = {e["uuid"]: e for e in model["elements"]}
assert len(model["outliner"]) == 4  # A, B, Swordeffect, C
assert len(model["animations"]) == 23
assert len(model["groups"]) == 48 and len(model["elements"]) == 51
assert len(set(groups) | set(meshes)) == len(groups) + len(meshes)
assert len(source["groups"]) == 2 and len(source["elements"]) == 2
assert {g["name"] for g in source["groups"]} == {"頭", "首"}
root = model["outliner"][-1]
paths = {}
def walk(node, ancestor=()):
    group = groups[node["uuid"]]
    parents = ancestor + (group["name"],)
    for c in node["children"]:
        if isinstance(c, dict):
            walk(c, parents)
        else:
            paths[meshes[c]["name"]] = parents
walk(root)
assert paths == {
    "HeadC_Neck_tube": ("Waist3","Torso3","Chest3","Neck3"),
    "HeadC_Head_torus": ("Waist3","Torso3","Chest3","Neck3","Head3"),
}
assert groups[root["uuid"]]["origin"] == [0, 17, 0]
assert next(g["origin"] for g in groups.values() if g["name"] == "Neck3") == [0, 23, 0]
assert next(g["origin"] for g in groups.values() if g["name"] == "Head3") == [0, 25, 0]
assert meshes[next(k for k,v in meshes.items() if v["name"] == "HeadC_Neck_tube")]["origin"] == [0, 12.1, -0.8]
assert meshes[next(k for k,v in meshes.items() if v["name"] == "HeadC_Head_torus")]["origin"] == [0, 20.7, 3.3]
assert all(meshes[k]["rotation"] == [0,0,0] for k in meshes if meshes[k]["name"].startswith("HeadC_"))
for m in model["elements"]:
    if m["name"].startswith("HeadC_"):
        assert len(m["vertices"]) > 0 and len(m["faces"]) > 0
embedded = (ROOT / "assets/sera_equipment_data.gd").read_text(encoding="utf-8")
parts = [json.loads(line.strip().rstrip(",")) for line in embedded.splitlines()
         if line.lstrip().startswith('"')]
snapshot = json.loads("".join(parts))
for name in ("groups","elements","outliner"):
    assert snapshot[name] == model[name]
loader = (ROOT / "scripts/sera_equipment.gd").read_text(encoding="utf-8")
assert "func options_for(slot: String)" in loader
assert "var letter: String = String.chr(65 + index)" in loader
assert 'return "head"' in loader
assert (ROOT / "README_v186_ja.md").is_file()
print("PASS: Head C attached to standard Neck/Head, head-only C, embedded snapshot matches")
print("Godot/Android runtime NOT TESTED")
