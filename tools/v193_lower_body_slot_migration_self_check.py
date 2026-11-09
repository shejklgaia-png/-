#!/usr/bin/env python3
"""v193: complete humanoid LOWER BODY D, bird C, removed FEET and safe save migration."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
project = (ROOT / "project.godot").read_text(encoding="utf-8")
if not re.search(r'^config/name="SERA v193"$', project, re.M):
    print("SKIP: v193-only lower-body test")
    raise SystemExit(0)

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")
eq = read("scripts/sera_equipment.gd")
nexus = read("scripts/command_nexus.gd")
save = read("scripts/sera_save.gd")
rig = read("scripts/sera_rig.gd")
main = read("scripts/main.gd")
source_model = json.loads(read("models/SERA_BOOSTER_allテスト.bbmodel"))
original_foot = json.loads(read("models/storage/足C.bbmodel"))
bird_source = json.loads(read("models/storage/SERA_BIRD_LEGS_MIRROR_EDIT.bbmodel"))
base = json.loads(read("assets/sera_source.json"))

def has_all(s: str, *chunks: str) -> None:
    for chunk in chunks:
        assert chunk in s, f"Missing {chunk!r}"

# Seven customization categories: both foot C and bird are alternative
# LOWER BODY assemblies, *not* an eighth independent FEET selection.
seven_slots = '["head", "torso", "legs", "arms", "booster", "weapon_r", "weapon_l"]'
assert f"const SLOTS = {seven_slots}" in eq
assert f"const EQUIPMENT_SLOTS = {seven_slots}" in save
assert f"const CUSTOMIZE_SLOTS = {seven_slots}" in nexus
assert '"feet": "FEET"' not in nexus
assert 'slot == "feet"' not in eq

# C = the preexisting bird subrig; D = ten meshes of the new
# normal-human lower-body. The Head C branch remains HEAD=C.
has_all(eq,
    '_add_mesh("C", "legs", child)',
    'var equipment_set: String = "D" if set_id == "C" and slot == "legs" else set_id',
    'if set_id == "C" and _simple_name(str(group.get("name", ""))) == "head":',
    '_add_mesh(equipment_set, slot, piece)',
    'piece.visible = set_id == str(selected.get(slot, "A"))',
    '_apply_legs_grounding(str(selected.get("legs", "A")))',
    'foot_meshes.get(str(selected.get("legs", "A")), {})',
    'func set_grounding_enabled(enabled: bool)',
)
assert 'equipment_set, "feet"' not in eq
has_all(rig,
    '_install_bird_model()', '_merge_bird_animation_tracks()',
    'func set_exhibition_mode(enabled: bool) -> void:',
    'equipment_handler.call("set_grounding_enabled", not enabled)',
    'foot_contact.emit(side)',
)
has_all(nexus,
    '"legs": "LOWER BODY"',
    'variant_label = "BIRD"',
    'variant_label = "NEW"',
    'rig.call("set_exhibition_mode", true)',
)
has_all(main, '_update_equipped_collision_height()', 'footstep_audio.play()')

# v1 -> v2 save schema. Prevent perpetual C/D swap on each save/load.
has_all(save,
    "const SCHEMA_VERSION: int = 2",
    "stored_version not in [1, SCHEMA_VERSION]",
    '_sanitize_equipment(data["equipment"], stored_version == 1)',
    'data["schema_version"] = SCHEMA_VERSION',
    "func _sanitize_equipment(candidate: Variant, legacy: bool = false) -> Dictionary:",
    'if old_legs == "D":',
    'clean["legs"] = "C"',
    'elif old_legs == "C" or old_feet == "C":',
    'clean["legs"] = "D"',
)
has_all(eq,
    'cfg.set_value("equipment", "schema_version", 2)',
    'int(cfg.get_value("equipment", "schema_version", 1)) < 2',
)
def migrate_legacy(legs, feet, legacy):
    if not legacy:
        return legs
    if legs == "D":  # bird before v193
        return "C"
    if legs == "C" or feet == "C":  # human new boot before v193
        return "D"
    return legs

for previous, foot, expected in [
    ("A", "A", "A"), ("B", "A", "B"),
    ("D", "A", "C"), ("D", "C", "C"),
    ("A", "C", "D"), ("B", "C", "D"),
    ("C", "A", "D"), ("C", "C", "D")
]:
    assert migrate_legacy(previous, foot, True) == expected
for current in ("A", "B", "C", "D"):
    assert migrate_legacy(current, "A", False) == current

# Preserve original combined geometry without renaming the authoring
# source. The v191 leg material had 10 actual complete-set meshes.
g = {n["uuid"]: n["name"] for n in source_model["groups"]}
e = {n["uuid"]: n["name"] for n in source_model["elements"]}
roots = {g[r["uuid"]]: r for r in source_model["outliner"] if isinstance(r, dict)}
assert "Waist3" in roots
def collect(nodes, names, group_names):
    for node in nodes:
        if isinstance(node, str):
            names.append(e[node])
        else:
            group_names.append(g[node["uuid"]])
            collect(node["children"], names, group_names)
names, groups = [], []
collect(roots["Waist3"]["children"], names, groups)
assert len([x for x in names if x.startswith("FootC_Base_")]) == 6
assert len([x for x in names if re.fullmatch(r"FootC_[LR]_[12]", x)]) == 4
assert {"Thigh_L3", "LowerLeg_L3", "Foot_L3",
        "Thigh_R3", "LowerLeg_R3", "Foot_R3"}.issubset(groups)
assert {"Head3", "Neck3"}.issubset(groups)
assert len(original_foot["elements"]) == 12
assert len([q for q in bird_source["groups"] if q["name"].startswith("Bird_")]) == 6
assert len(base["groups"]) == 22 and len(base["elements"]) == 25
assert len(source_model["animations"]) == 23

# No model snapshot regeneration needed: only new *routing* changed.
text = read("assets/sera_equipment_data.gd")
chunks = [json.loads(line.strip().removesuffix(",")) for line in text.splitlines()
          if line.startswith('    "')]
snapshot = json.loads("".join(chunks))
for key in ("groups", "elements", "outliner"):
    assert snapshot[key] == source_model[key]
assert (ROOT / "README_v193_ja.md").exists()
print("PASS: LOWER BODY A/B/C bird/D new human full leg, independent HEAD C")
print("PASS: FEET UI removed, one-time v1->v2 selection migration and preview isolation")
print("PASS: 10 source meshes + 6 standard joints preserved; A clips/snapshot unchanged")
print("Godot/Xperia Android runtime not exercised")
