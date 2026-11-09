#!/usr/bin/env python3
"""v164 static validation for interchangeable six-slot SERA equipment."""
from __future__ import annotations

import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
cfg = (root / "project.godot").read_text(encoding="utf-8")
rig = (root / "scripts/sera_rig.gd").read_text(encoding="utf-8")
equip = (root / "scripts/sera_equipment.gd").read_text(encoding="utf-8")
nexus = (root / "scripts/command_nexus.gd").read_text(encoding="utf-8")
assert re.findall(r'^config/name="([^"]+)"$', cfg, re.M) == ["SERA v164"]
slots = ["head", "torso", "legs", "arms", "weapon_r", "weapon_l"]
assert all('"' + x + '"' in equip and '"' + x + '"' in nexus for x in slots)
for symbol in (
    "func setup(", "func select_part(", "func options_for(", "func _match_child_bone(",
    "func _slot_for_bone(", "func _restore_saved(", "func _save_selection(",
    "func _sync_afterimage_visibility(", 'user://sera_equipment.cfg',
):
    assert symbol in equip, symbol
for symbol in (
    'pivot.set_meta("bb_origin", origin)', "func get_equipment_options(",
    "func get_equipment_selection(", "func set_equipment_selection(",
    'equipment_handler.call("setup", self)',
    'equipment_handler.call("sync_afterimages")',
):
    assert symbol in rig, symbol
assert 'func _tap_equipment_control(' in nexus
assert 'func _refresh_equipment_controls(' in nexus
assert '_capture_sera_silhouette(sera_display_rig)' in nexus
assert 'if piece.mesh != null and piece.is_visible_in_tree():' in nexus

model = json.loads((root / "models/SERA_BOOSTER_allテスト.bbmodel").read_text(encoding="utf-8"))
groups = {g["uuid"]: g for g in model["groups"]}
elements = {m["uuid"]: m for m in model["elements"]}
roots = [r for r in model["outliner"] if isinstance(r, dict)
         and groups[r["uuid"]]["name"].startswith("Waist")]
assert len(roots) >= 2, "Source requires A and B roots"
assert any(groups[g]["name"].startswith("Head2") for g in groups), "B head joint is required"

# Mesh names are deliberately NOT required: the head has already been renamed
# from Head_Mesh to sphere. Folder structure, not mesh name, selects its slot.
mesh_in_head = []
def walk(entry, path):
    name = groups[entry["uuid"]]["name"]
    path = path + [name]
    for child in entry.get("children", []):
        if isinstance(child, dict):
            walk(child, path)
        elif child in elements and any(part.startswith("Head2") for part in path):
            mesh_in_head.append(elements[child]["name"])
walk(roots[1], [])
assert mesh_in_head and "sphere" in mesh_in_head

# The snapshot must match the working model's geometry/hierarchy after rebuild.
embedded = (root / "assets/sera_equipment_data.gd").read_text(encoding="utf-8")
parts = [json.loads(line.strip().rstrip(",")) for line in embedded.splitlines()
         if line.lstrip().startswith('"')]
decoded = json.loads("".join(parts))
for key in ("groups", "elements", "outliner"):
    assert decoded[key] == model[key], key
assert (root / "README_v164_ja.md").is_file()
print("v164 equipment set roots, 6 slot paths, renamed sphere, save/UI, snapshot: STATIC PASS")
print("Godot parser and Android device runtime: NOT TESTED")
