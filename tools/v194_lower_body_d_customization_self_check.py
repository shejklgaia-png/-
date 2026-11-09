#!/usr/bin/env python3
"""v194 regression: D is loaded ONLY from its dedicated 12-mesh A-rig source."""
from __future__ import annotations

import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

def get(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

def load(path: str) -> dict:
    return json.loads(get(path))

project = get("project.godot")
version = re.search(r'^config/name="SERA v(\\d+)"
code = get("scripts/sera_equipment.gd")
model = load("models/storage/SERA_LOWER_BODY_D_STANDARD_READY.bbmodel")
combined = load("models/SERA_BOOSTER_allテスト.bbmodel")
author = load("models/storage/SERA_LEGS_C_AUTHOR_NORMALIZED.bbmodel")
base = load("assets/sera_source.json")
embedded = get("assets/sera_lower_body_d_data.gd")

# Export fallback is independently embedded and exactly matches the standalone file.
chunks = [json.loads(line.strip().removesuffix(",")) for line in embedded.splitlines()
          if line.startswith('    "')]
snapshot = json.loads("".join(chunks))
for key in ("groups", "elements", "outliner"):
    assert snapshot[key] == model[key], "Embedded D snapshot differs: " + key

# Only seven familiar A joints are used; no new animated skeleton is introduced.
groups = {g["uuid"]: g for g in model["groups"]}
elems = {m["uuid"]: m for m in model["elements"]}
assert len(groups) == 7 and len(elems) == 12
assert len(model["outliner"]) == 1
assert "animations" not in model or not model["animations"]
assert set(g["name"] for g in groups.values()) == {
    "Waist3", "Thigh_L3", "Thigh_R3", "LowerLeg_L3",
    "LowerLeg_R3", "Foot_L3", "Foot_R3"}
assert len(author["elements"]) == 12

integrated_groups = {g["uuid"]: g for g in combined["groups"]}
integrated_elements = {m["uuid"]: m for m in combined["elements"]}
for uid, group in groups.items():
    assert integrated_groups[uid] == group
for uid, mesh in elems.items():
    assert integrated_elements[uid] == mesh
    assert mesh["name"].startswith("LegD_")

# The D set must not accidentally pick up A's default foot meshes.
assert not any(m["name"].startswith("Foot_") and not m["name"].startswith("LegD_")
               for m in model["elements"])
assert len({m["name"] for m in model["elements"]}) == 12
assert len(base["elements"]) == 25
assert len(combined["animations"]) == 23

# Compare normalized D with A. All 12 parts are authored; A has two foot meshes.
assert len([e for e in base["elements"] if e["name"].startswith("Foot_")]) == 2
assert len([e for e in model["elements"] if e["name"].startswith("LegD_Foot_")]) == 4

# Runtime correctness: D must be installed BEFORE restoring saves / visibility,
# and C's shared Waist3 root must not register duplicate D geometry.
assert 'const LOWER_BODY_D_SOURCE: String = "res://models/storage/SERA_LOWER_BODY_D_STANDARD_READY.bbmodel"' in code
assert 'const LOWER_BODY_D_EMBEDDED = preload("res://assets/sera_lower_body_d_data.gd")' in code
assert 'func _install_standard_lower_body_d() -> void:' in code
assert 'func _read_standard_lower_body_d() -> Dictionary:' in code
assert "var imported: Array = (available.get(\"D\", {}) as Dictionary).get(\"legs\", [])" in code
assert 'if imported.size() != 12:' in code
assert 'if set_id == "C" and slot == "legs":' in code
assert 'var equipment_set: String = "D" if set_id == "C" and slot == "legs" else set_id' in code
assert code.index('_install_alternative_sets(data)') < code.index('_install_standard_lower_body_d()') < code.index('_cache_bind_foot_geometry()')
assert 'piece.visible = set_id == str(selected.get(slot, "A"))' in code
assert 'if slot == "legs":\n        _apply_legs_grounding(set_id)' in code
assert 'cfg.set_value("equipment", "schema_version", 2)' in code

nexus = get("scripts/command_nexus.gd")
assert '"legs": "LOWER BODY"' in nexus
assert 'variant_label = "BIRD"' in nexus
assert 'variant_label = "NEW"' in nexus
print("PASS: D uses isolated, author-derived 12-mesh asset and export snapshot")
print("PASS: no duplicate D, dedicated standard joints, C bird and head routing preserved")
print("PASS: visibility, saved D selection and foot grounding paths retained")
print("Godot/Xperia Android runtime appearance not verified")
, project, re.M)
assert version and int(version.group(1)) >= 194
code = get("scripts/sera_equipment.gd")
model = load("models/storage/SERA_LOWER_BODY_D_STANDARD_READY.bbmodel")
combined = load("models/SERA_BOOSTER_allテスト.bbmodel")
author = load("models/storage/SERA_LEGS_C_AUTHOR_NORMALIZED.bbmodel")
base = load("assets/sera_source.json")
embedded = get("assets/sera_lower_body_d_data.gd")

# Export fallback is independently embedded and exactly matches the standalone file.
chunks = [json.loads(line.strip().removesuffix(",")) for line in embedded.splitlines()
          if line.startswith('    "')]
snapshot = json.loads("".join(chunks))
for key in ("groups", "elements", "outliner"):
    assert snapshot[key] == model[key], "Embedded D snapshot differs: " + key

# Only seven familiar A joints are used; no new animated skeleton is introduced.
groups = {g["uuid"]: g for g in model["groups"]}
elems = {m["uuid"]: m for m in model["elements"]}
assert len(groups) == 7 and len(elems) == 12
assert len(model["outliner"]) == 1
assert "animations" not in model or not model["animations"]
assert set(g["name"] for g in groups.values()) == {
    "Waist3", "Thigh_L3", "Thigh_R3", "LowerLeg_L3",
    "LowerLeg_R3", "Foot_L3", "Foot_R3"}
assert len(author["elements"]) == 12

integrated_groups = {g["uuid"]: g for g in combined["groups"]}
integrated_elements = {m["uuid"]: m for m in combined["elements"]}
for uid, group in groups.items():
    assert integrated_groups[uid] == group
for uid, mesh in elems.items():
    assert integrated_elements[uid] == mesh
    assert mesh["name"].startswith("LegD_")

# The D set must not accidentally pick up A's default foot meshes.
assert not any(m["name"].startswith("Foot_") and not m["name"].startswith("LegD_")
               for m in model["elements"])
assert len({m["name"] for m in model["elements"]}) == 12
assert len(base["elements"]) == 25
assert len(combined["animations"]) == 23

# Compare normalized D with A. All 12 parts are authored; A has two foot meshes.
assert len([e for e in base["elements"] if e["name"].startswith("Foot_")]) == 2
assert len([e for e in model["elements"] if e["name"].startswith("LegD_Foot_")]) == 4

# Runtime correctness: D must be installed BEFORE restoring saves / visibility,
# and C's shared Waist3 root must not register duplicate D geometry.
assert 'const LOWER_BODY_D_SOURCE: String = "res://models/storage/SERA_LOWER_BODY_D_STANDARD_READY.bbmodel"' in code
assert 'const LOWER_BODY_D_EMBEDDED = preload("res://assets/sera_lower_body_d_data.gd")' in code
assert 'func _install_standard_lower_body_d() -> void:' in code
assert 'func _read_standard_lower_body_d() -> Dictionary:' in code
assert "var imported: Array = (available.get(\"D\", {}) as Dictionary).get(\"legs\", [])" in code
assert 'if imported.size() != 12:' in code
assert 'if set_id == "C" and slot == "legs":' in code
assert 'var equipment_set: String = "D" if set_id == "C" and slot == "legs" else set_id' in code
assert code.index('_install_alternative_sets(data)') < code.index('_install_standard_lower_body_d()') < code.index('_cache_bind_foot_geometry()')
assert 'piece.visible = set_id == str(selected.get(slot, "A"))' in code
assert 'if slot == "legs":\n        _apply_legs_grounding(set_id)' in code
assert 'cfg.set_value("equipment", "schema_version", 2)' in code

nexus = get("scripts/command_nexus.gd")
assert '"legs": "LOWER BODY"' in nexus
assert 'variant_label = "BIRD"' in nexus
assert 'variant_label = "NEW"' in nexus
print("PASS: D uses isolated, author-derived 12-mesh asset and export snapshot")
print("PASS: no duplicate D, dedicated standard joints, C bird and head routing preserved")
print("PASS: visibility, saved D selection and foot grounding paths retained")
print("Godot/Xperia Android runtime appearance not verified")
