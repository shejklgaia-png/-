#!/usr/bin/env python3
"""v195 visual fidelity: preserve exact C author geometry/UVs, test D visible size."""
from __future__ import annotations
import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def text(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")
def read(path: str) -> dict:
    return json.loads(text(path))

match = re.search(r'^config/name="SERA v(\d+)"$', text("project.godot"), re.M)
assert match and int(match.group(1)) >= 195
source = read("models/storage/SERA_LEGS_C_AUTHOR_NORMALIZED.bbmodel")
d = read("models/storage/SERA_LOWER_BODY_D_STANDARD_READY.bbmodel")
combined = read("models/SERA_BOOSTER_allテスト.bbmodel")
src = {m["name"]: m for m in source["elements"]}
dst = {m["name"]: m for m in d["elements"]}
registered = {m["uuid"]: m for m in combined["elements"]}
assert len(src) == len(dst) == 12
assert len(d["groups"]) == 7
SCALE = 0.36
SOLE_Y = 0.2

def world(mesh):
    return [
        tuple(mesh["origin"][axis] + vertex[axis] for axis in range(3))
        for vertex in mesh["vertices"].values()
    ]
def bnds(elements):
    v = [p for e in elements for p in world(e)]
    lo = tuple(min(x[i] for x in v) for i in range(3))
    hi = tuple(max(x[i] for x in v) for i in range(3))
    return lo, hi

for src_name, authored in src.items():
    destination_name = src_name.replace("LegC_", "LegD_", 1)
    out = dst[destination_name]
    assert registered[out["uuid"]] == out, destination_name
    assert authored["faces"] == out["faces"], destination_name
    assert set(authored["vertices"]) == set(out["vertices"]), destination_name
    assert authored["color"] == out["color"], destination_name
    for uid, point in authored["vertices"].items():
        for axis in range(3):
            original_world = authored["origin"][axis] + point[axis]
            new_world = out["origin"][axis] + out["vertices"][uid][axis]
            expected = (original_world - (SOLE_Y if axis == 1 else 0.0)) * SCALE
            assert math.isclose(new_world, expected, abs_tol=2e-7), (src_name, uid, axis)

raw_low, raw_high = bnds(source["elements"])
low, high = bnds(d["elements"])
for axis in range(3):
    assert math.isclose(high[axis] - low[axis],
                        (raw_high[axis] - raw_low[axis]) * SCALE,
                        abs_tol=1e-6)
assert math.isclose(low[1], 0, abs_tol=1e-6)
assert high[0] - low[0] > 15.0  # Old per-part fit was 8.64 total.
feet = [e for e in d["elements"] if "_Foot_" in e["name"]]
assert len(feet) == 4
feet_min, feet_max = bnds(feet)
assert feet_max[2] - feet_min[2] > 11.0 # Old boots were 8.96 total.
# The original 23 clips remain; later versions may append new animations.
assert len(combined["animations"]) >= 23

gd = text("scripts/sera_equipment.gd")
assert 'if set_id == "D":' in gd
assert 'material_d.albedo_texture = null' in gd
assert 'material_d.albedo_color = Color("#ce8585")' in gd
assert 'material_d.albedo_color = Color("#adc7df")' in gd
assert '_apply_equipment_tint(piece, equipment_set, int(element.get("color", -1)))' in gd
assert 'func _install_standard_lower_body_d() -> void:' in gd
assert 'if set_id == "C" and slot == "legs":' in gd
assert len([x for x in d["elements"] if x["name"].startswith("LegD_")]) == 12

# Both embedded snapshots must match their respective source models.
for embedded_path, model in [
    ("assets/sera_lower_body_d_data.gd", d),
    ("assets/sera_equipment_data.gd", combined),
]:
    chunks = [json.loads(line.strip().removesuffix(","))
              for line in text(embedded_path).splitlines()
              if line.startswith('    "')]
    packed = json.loads("".join(chunks))
    for name in ("groups", "elements", "outliner"):
        assert packed[name] == model[name], (embedded_path, name)

print("PASS: all 12 authored world shapes, UVs and segment colors preserved")
print("PASS: equal XYZ scale, sole anchored and markedly larger D footprint")
print("PASS: Godot D material routing and both embedded snapshots updated")
print("Godot Android rendered appearance, gait and ground detection require device check")
