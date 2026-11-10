#!/usr/bin/env python3
"""v205 static regression: Chest booster, hollow octagonal nozzles, live/embedded loader."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
model = json.loads((root / "models/SERA_BOOSTER_allテスト.bbmodel").read_text(encoding="utf-8"))
groups = {g["uuid"]: g for g in model["groups"]}
elements = {e["uuid"]: e for e in model["elements"]}
assert len(groups) == len(model["groups"]) == 57, "Lost group / UUID"
assert len(elements) == len(model["elements"]) == 68, "Lost element / UUID"
assert set(groups).isdisjoint(elements), "Group/element UUID collision"

def find(entry, name):
    if not isinstance(entry, dict):
        return None
    if groups[entry["uuid"]]["name"] == name:
        return entry
    for child in entry.get("children", []):
        found = find(child, name)
        if found is not None:
            return found
    return None

chest = find(model["outliner"][0], "Chest")
assert chest
booster = find(chest, "BOOSTER")
assert booster and len(booster["children"]) == 3
assert elements[booster["children"][0]]["name"] == "BoosterBody"
body = elements[booster["children"][0]]
assert len(body["vertices"]) == 8 and len(body["faces"]) == 6
left, right = (find(booster, "Thruster_L"), find(booster, "Thruster_R"))
assert left and right
for side, prefix in [(left, "Thruster_L"), (right, "Thruster_R")]:
    assert len(side["children"]) == 2
    outer = elements[side["children"][0]]
    inner = elements[side["children"][1]]
    assert outer["name"] == prefix + "_Outer"
    assert len(outer["vertices"]) == 32 and len(outer["faces"]) == 32
    assert all(len(face["vertices"]) == 4 for face in outer["faces"].values())
    assert inner["name"] == prefix + "_Inner"
    assert len(inner["vertices"]) == 8 and len(inner["faces"]) == 1
assert groups[left["uuid"]]["origin"][0] == -groups[right["uuid"]]["origin"][0]
assert groups[left["uuid"]]["origin"][1:] == groups[right["uuid"]]["origin"][1:]
assert len(model["animations"]) == 23

generated = (root / "assets/sera_equipment_data.gd").read_text(encoding="utf-8")
chunks = []
for line in generated.splitlines():
    line = line.strip()
    if line.startswith('"') and line.endswith('",'):
        chunks.append(json.loads(line[:-1]))
assert chunks, "Missing embedded payload"
assert json.loads("".join(chunks)) == {key: model[key] for key in ("groups", "elements", "outliner")}

equip = (root / "scripts/sera_equipment.gd").read_text(encoding="utf-8")
for phrase in (
    "_install_back_booster_placeholder(data)",
    '_find_outliner_group(a_chest_entry, groups, "BOOSTER")',
    'rig.get_node_or_null("Waist/Torso/Chest")',
    'for set_id in ["A", "B"]:',
    '_add_mesh(set_id, "booster", piece)',
):
    assert phrase in equip, phrase
import re
version = re.search(r'config/name="SERA v(\d+)"', (root / "project.godot").read_text(encoding="utf-8"))
assert version and int(version.group(1)) >= 205
print("v205 booster authoring and in-game import checks passed")
