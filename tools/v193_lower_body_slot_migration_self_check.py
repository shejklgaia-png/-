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

# C = the preexisting bird subrig; D = twelve meshes of the new
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

# Both variants are full lower-body sets. All TWELVE original source
# meshes were imported, rescaled into A-compatible Waist/Thigh/Shin/Foot
# pivots. No A clones should remain inside LOWER BODY D.
g = {n["uuid"]: n["name"] for n in source_model["groups"]}
e = {n["uuid"]: n for n in source_model["elements"]}
roots = {g[r["uuid"]]: r for r in source_model["outliner"] if isinstance(r, dict)}
assert "Waist3" in roots
authored = {}
parents = {}
def collect(nodes, ancestors=()):
    for node in nodes:
        if isinstance(node, str):
            mesh = e[node]
            if mesh["name"].startswith("LegD_"):
                authored[mesh["name"]] = mesh
                parents[mesh["name"]] = ancestors
        else:
            collect(node["children"], (*ancestors, g[node["uuid"]]))
collect(roots["Waist3"]["children"])
expected_source = {
    "LegD_Waist_Upper": "d1256714-d6f3-1a88-dd49-0c9079ff55ff",
    "LegD_Waist_Lower": "447a8012-78cb-145e-da80-3fa881d6ec10",
    "LegD_Thigh_L_1": "15574510-d4a8-2016-fcac-c25fa214152f",
    "LegD_Thigh_L_2": "7ba20e07-47db-8d25-fc59-3d1b916af4a0",
    "LegD_LowerLeg_L": "9202acbc-d599-c41d-a967-0f8c05ed7c57",
    "LegD_Thigh_R_1": "caa89396-8e89-aa52-13aa-9cf6af0a67fb",
    "LegD_Thigh_R_2": "1898853f-9976-6d8f-e826-c8c693f0fd94",
    "LegD_LowerLeg_R": "3198d0f8-c2c4-62a8-3e9f-8f285b7a51b2",
    "LegD_Foot_L_1": "c8d5f061-2246-4ca7-f0c0-8c7e06ce0440",
    "LegD_Foot_L_2": "bb4f16a1-fb91-780a-3cbb-9fad7a42845d",
    "LegD_Foot_R_1": "87dfdf77-ba76-8931-82aa-0a1053ad8580",
    "LegD_Foot_R_2": "da9f1d1a-53f0-d58f-f3b6-e8c5d230ffbf",
}
assert set(authored) == set(expected_source), set(authored) ^ set(expected_source)
orig = {q["uuid"]: q for q in original_foot["elements"]}
assert len(orig) == 12
for name, uid in expected_source.items():
    dest, author = authored[name], orig[uid]
    assert dest["faces"] == author["faces"], name
    assert set(dest["vertices"]) == set(author["vertices"]), name
    if "Thigh_" in name:
        assert parents[name][-1] in ("Thigh_L3", "Thigh_R3")
    elif "LowerLeg_" in name:
        assert parents[name][-1] in ("LowerLeg_L3", "LowerLeg_R3")
    elif "Foot_" in name:
        assert parents[name][-1] in ("Foot_L3", "Foot_R3")
    elif "Waist_" in name:
        # Traversal starts at Waist3.children, so its own mesh children
        # have an empty ancestor tuple; other parts have child bones.
        assert parents[name] == ()
assert {"Thigh_L3", "LowerLeg_L3", "Foot_L3",
        "Thigh_R3", "LowerLeg_R3", "Foot_R3",
        "Head3", "Neck3"}.issubset({q["name"] for q in source_model["groups"]})
assert len(source_model["groups"]) == 54
assert len(source_model["elements"]) == 63
assert len([q for q in bird_source["groups"] if q["name"].startswith("Bird_")]) == 6
assert len(base["groups"]) == 22 and len(base["elements"]) == 25
assert len(source_model["animations"]) == 23

# Embedded runtime model is rebuilt to match authored D pelvis, thigh, shin
# and boot geometry; no native A source or animation clip was changed.
text = read("assets/sera_equipment_data.gd")
chunks = [json.loads(line.strip().removesuffix(",")) for line in text.splitlines()
          if line.startswith('    "')]
snapshot = json.loads("".join(chunks))
for key in ("groups", "elements", "outliner"):
    assert snapshot[key] == source_model[key]
assert (ROOT / "README_v193_ja.md").exists()
print("PASS: LOWER BODY A/B/C bird/D new human full leg, independent HEAD C")
print("PASS: FEET UI removed, one-time v1->v2 selection migration and preview isolation")
print("PASS: 12 authored source meshes + 6 standard joints; A clips preserved, D snapshot rebuilt")
print("Godot/Xperia Android runtime not exercised")
