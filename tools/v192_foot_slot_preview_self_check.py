#!/usr/bin/env python3
"""SERA v192: independent Foot C choices and safe Nexus exhibition pose."""
from __future__ import annotations
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
project = (ROOT / "project.godot").read_text(encoding="utf-8")
if not re.search(r'^config/name="SERA v192"$', project, re.M):
    print("SKIP: this self-test validates v192 only")
    raise SystemExit(0)

def contains(contents, *tokens):
    for token in tokens:
        assert token in contents, token

equip = (ROOT / "scripts/sera_equipment.gd").read_text(encoding="utf-8")
rig = (ROOT / "scripts/sera_rig.gd").read_text(encoding="utf-8")
nexus = (ROOT / "scripts/command_nexus.gd").read_text(encoding="utf-8")
save = (ROOT / "scripts/sera_save.gd").read_text(encoding="utf-8")
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")

contains(equip,
    '"legs", "feet", "arms"',
    'if slot == "feet":',
    'return ["A", "C"] if (c_parts.get("feet", []) as Array).size() == 4 else ["A"]',
    'if slot == "legs" and str(set_id) == "C":',
    'if set_id == "C" and str(piece.name).begins_with("C_FootC_"):',
    '_add_mesh(set_id, "feet", piece)',
    'func _apply_part_visibility() -> void:',
    'piece.visible = set_id == chosen_feet and chosen_legs != "D"',
    'piece.visible = set_id == chosen_legs and (',
    'not is_shoe or set_id == "D" or chosen_feet == "A")',
    'func _active_foot_variant() -> String:',
    'if legs == "D":',
    'if str(selected.get("feet", "A")) == "C":',
    'func set_grounding_enabled(enabled: bool) -> void:',
    'if not grounding_enabled:',
    'rig.position.y = rig_original_y',
    'candidates.append_array(source_parts.get("legs", []))',
    'candidates.append_array(source_parts.get("feet", []))',
    'var feet: Dictionary = foot_meshes.get(_active_foot_variant(), {})',
    'if old_legs == "C":',
)
contains(rig,
    'func set_exhibition_mode(enabled: bool) -> void:',
    'equipment_handler.call("set_grounding_enabled", not enabled)',
    'func get_equipment_options(slot: String) -> Array:',
    'func set_equipment_selection(slot: String, set_id: String) -> bool:',
)
contains(nexus,
    'const CUSTOMIZE_SLOTS = ["head", "torso", "legs", "feet", "arms"',
    '"feet": "FEET"',
    'rig.call("set_exhibition_mode", true)',
    'variant_label = "STD" if current_set == "A" else "BOOT"',
    '_capture_sera_silhouette(sera_display_rig)',
)
# Ensure exhibition disables ground lift after creation but BEFORE capturing
# original transform and screen-fitting anchors.
nexus_start = nexus.index("func _sera_display() -> void:")
preview = nexus[nexus_start:nexus.index("func _apply_nexus_pose", nexus_start)]
assert preview.index("stand.add_child(rig)") < preview.index(
    'rig.call("set_exhibition_mode", true)') < preview.index(
    "sera_original_transform = rig.transform")
assert nexus.count('rig.call("set_exhibition_mode", true)') == 1
contains(save,
    'const EQUIPMENT_SLOTS = ["head", "torso", "legs", "feet", "arms"',
    'if clean["legs"] == "C":',
    'clean["legs"] = "A"',
    'clean["feet"] = "C"',
)
# The training floor and its footfall/contact system remain active.
contains(main, '_update_equipped_collision_height()', 'footstep_audio.play()')
contains(rig, 'foot_contact.emit(side)', 'func _update_foot_contacts(delta: float)')
assert 'rig.call("set_exhibition_mode", true)' not in main

m = json.loads((ROOT / "models/SERA_BOOSTER_allテスト.bbmodel").read_text(encoding="utf-8"))
src = json.loads((ROOT / "models/storage/足C.bbmodel").read_text(encoding="utf-8"))
names = {e["name"] for e in m["elements"]}
c_sole_names = {f"FootC_{side}_{j}" for side in ("L", "R") for j in (1, 2)}
assert c_sole_names.issubset(names)
assert sum(1 for e in src["elements"] if e["name"] == "mesh") == 12
assert {g["name"] for g in m["groups"]}.issuperset({
    "Foot_L3", "Foot_R3", "Thigh_L3", "Thigh_R3",
    "LowerLeg_L3", "LowerLeg_R3",
})
# For shoes exported in C's authoring tree, their A-origin parent positions
# are preserved so they inherit standard A foot animation.
g = {v["uuid"]: v["name"] for v in m["groups"]}
e = {v["uuid"]: v["name"] for v in m["elements"]}
shoe_parents = {}
def walk(children, ancestors=()):
    for child in children:
        if isinstance(child, str):
            if e[child] in c_sole_names:
                shoe_parents[e[child]] = ancestors
        else:
            walk(child["children"], (*ancestors, g[child["uuid"]]))
walk(m["outliner"])
assert len(shoe_parents) == 4
for name, parent_chain in shoe_parents.items():
    side = name.split("_")[1]
    assert parent_chain[-1] == f"Foot_{side}3"
    assert "Waist3" in parent_chain

# New function supports expected visibility for common selections and the
# bird-leg override, without hiding human thighs/shins for Foot C.
def display(variant, slot, feet, legs, is_foot):
    if slot == "feet":
        return variant == feet and legs != "D"
    if slot == "legs":
        return variant == legs and (not is_foot or variant == "D" or feet == "A")
    return False
for set_id in ("A", "B"):
    assert display(set_id, "legs", "C", set_id, False)
    assert not display(set_id, "legs", "C", set_id, True)
    assert display("C", "feet", "C", set_id, True)
    assert display(set_id, "legs", "A", set_id, True)
    assert not display("C", "feet", "A", set_id, True)
assert display("D", "legs", "C", "D", True)
assert not display("C", "feet", "C", "D", True)

assert (ROOT / "README_v192_ja.md").exists()
print("PASS: independent FEET A/C UI and save migration; D bird priority")
print("PASS: four Foot C meshes on standard A pivots; Nexus preview disables grounding")
print("PASS: training footfalls/grounding unaffected (static + numerical checks only)")
print("Godot Android visual/functional runtime: NOT RUN")
