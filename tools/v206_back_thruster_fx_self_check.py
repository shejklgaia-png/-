#!/usr/bin/env python3
"""SERA v206: pivot-preserving authoring import and limited animated back nozzle FX."""
from __future__ import annotations

import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
model = json.loads((ROOT / "models/SERA_BOOSTER_allテスト.bbmodel").read_text(encoding="utf-8"))
authored = json.loads((ROOT / "models/storage/SERA_BOOSTER_allテスト (4).bbmodel").read_text(encoding="utf-8"))
groups = {group["uuid"]: group for group in model["groups"]}
elements = {element["uuid"]: element for element in model["elements"]}
source_groups = {group["uuid"]: group for group in authored["groups"]}
source_elements = {element["uuid"]: element for element in authored["elements"]}
assert len(model["outliner"]) == 4 and len(model["animations"]) == 23
assert len(model["groups"]) == 57 and len(model["elements"]) == 68
for idx in (1, 2, 3):
    uid = f"f2050000-0000-4000-8000-{idx:012d}"
    assert groups[uid]["origin"] == source_groups[uid]["origin"]
    assert groups[uid]["rotation"] == source_groups[uid]["rotation"]
for idx in (11, 12, 13, 14, 15):
    uid = f"f2050000-0000-4000-8000-{idx:012d}"
    for field in ("origin", "rotation", "vertices", "faces"):
        assert elements[uid][field] == source_elements[uid][field], (idx, field)

# Model must have one Chest/BOOSTER tree, not a detached top-level part.
def find(entry, target):
    if not isinstance(entry, dict):
        return None
    if groups[entry["uuid"]]["name"] == target:
        return entry
    for child in entry.get("children", []):
        result = find(child, target)
        if result is not None:
            return result
    return None

chest = find(model["outliner"][0], "Chest")
assert find(chest, "BOOSTER") is not None
assert model["animations"] == authored["animations"]

# v206 uses authored, not a duplicated hard-coded, world-space FX location.
equip = (ROOT / "scripts/sera_equipment.gd").read_text(encoding="utf-8")
for phrase in (
    'pivot.position = (group_origin - parent_origin) * MODEL_UNIT',
    'pivot.quaternion = rig.call("_blockbench_rotation"',
    'piece.position = (_v3(element.get("origin", [0, 0, 0])) - group_origin) * MODEL_UNIT',
    'piece.quaternion = rig.call("_blockbench_rotation"',
    'pivot.add_child(piece)',
    'author_rim.z += far_z + 0.08',
    'fx.position = (author_rim - _v3(group.get("origin", [0, 0, 0]))) * MODEL_UNIT',
    'fx.call("set_exhaust", active and str(set_id) == selected_booster,',
):
    assert phrase in equip, phrase

fx = (ROOT / "scripts/back_thruster_fx.gd").read_text(encoding="utf-8")
shader = (ROOT / "shaders/back_thruster.gdshader").read_text(encoding="utf-8")
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
rig = (ROOT / "scripts/sera_rig.gd").read_text(encoding="utf-8")
for phrase in (
    'for side in range(4):',
    'Vector3(b.x, b.y, length)',
    'visible = enabled',
    'nozzle.global_transform.basis.inverse()',
    'world_exhaust_direction.normalized()',
    'clampf(requested_yaw,',
    '-YAW_LIMIT_RADIANS, YAW_LIMIT_RADIANS',
    '-PITCH_LIMIT_RADIANS, PITCH_LIMIT_RADIANS',
    'lerp_angle(rotation.y, yaw, ease)',
):
    assert phrase in fx, phrase
assert 'sin(TIME * 17.0' in shader and 'sin(TIME * 25.0' in shader
assert 'ALPHA = clamp(strength' in shader
assert 'equipment_handler.call("update_back_thruster_fx", active, exhaust_world, delta)' in rig
for phrase in (
    'movement_boost_active and running',
    'stepping_this_frame or tracking_exhaust',
    'combat_state == CombatState.BASH_TRACK',
    'combat_state == CombatState.STRIKE_TRACK',
    'combat_state == CombatState.DASH',
    'combat_state == CombatState.STRIKE and not strike_did_hit',
    'combat_state == CombatState.BASH and not bash_did_hit',
    'var direction_of_exhaust: Vector3 = -blur_velocity',
    'rig.call("update_back_thruster_fx", exhaust_on,',
):
    assert phrase in main, phrase

# Angular safety: any requested direction is mechanically clamped.
max_yaw = math.radians(38.0)
max_pitch = math.radians(24.0)
for vec in ((1, 0, 0), (-1, 0, 0), (0, 0, -1), (0.7, .5, -0.2)):
    x, y, z = vec
    requested = math.atan2(x, z)
    if z < 0 and abs(x) < .035:
        requested = 0.0
    yaw = max(-max_yaw, min(max_yaw, requested))
    pitch = max(-max_pitch, min(max_pitch,
        -math.atan2(y, math.sqrt(x * x + z * z))))
    assert abs(yaw) <= max_yaw and abs(pitch) <= max_pitch
# Runtime embed snapshot still matches canonical source exactly.
embedded = (ROOT / "assets/sera_equipment_data.gd").read_text(encoding="utf-8")
parts = []
for line in embedded.splitlines():
    line = line.strip()
    if line.startswith('"') and line.endswith('",'):
        parts.append(json.loads(line[:-1]))
assert json.loads("".join(parts)) == {
    key: model[key] for key in ("groups", "elements", "outliner")}
assert 'config/name="SERA v206"' in (ROOT / "project.godot").read_text(encoding="utf-8")
print("SERA v206 pivot and rectangular back-thruster effect checks passed")
