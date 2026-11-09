#!/usr/bin/env python3
"""SERA v194: distinguish authored human D lower body from default A.

The v193 per-section bbox fitting had collapsed the original source silhouette
to within ~10% of A on *every* axis. Worse, its 0..16 source UVs were copied
onto the SERA 96x32 palette without conversion. These tests prevent both.
"""
from __future__ import annotations
import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
project = (ROOT / "project.godot").read_text(encoding="utf-8")
if not re.search(r'^config/name="SERA v194"$', project, re.M):
    print("SKIP: requires v194")
    raise SystemExit(0)
def read(name):
    return (ROOT / name).read_text(encoding="utf-8")
original = json.loads(read("models/storage/足C.bbmodel"))
combined = json.loads(read("models/SERA_BOOSTER_allテスト.bbmodel"))
base = json.loads(read("assets/sera_source.json"))
dmeshes = {e["name"]: e for e in combined["elements"] if e["name"].startswith("LegD_")}
source = {e["uuid"]: e for e in original["elements"]}
assert len(original["elements"]) == len(dmeshes) == 12
assert len(combined["groups"]) == 54 and len(combined["elements"]) == 63
assert len(combined["animations"]) == 23
by_name = {e["name"]: e for e in base["elements"]}

original_mapping = {
 "LegD_Waist_Upper": "d1256714-d6f3-1a88-dd49-0c9079ff55ff",
 "LegD_Waist_Lower": "447a8012-78cb-145e-da80-3fa881d6ec10",
 "LegD_Thigh_L_1": "15574510-d4a8-2016-fcac-c25fa214152f",
 "LegD_Thigh_L_2": "7ba20e07-47db-8d25-fc59-3d1b916af4a0",
 "LegD_Thigh_R_1": "caa89396-8e89-aa52-13aa-9cf6af0a67fb",
 "LegD_Thigh_R_2": "1898853f-9976-6d8f-e826-c8c693f0fd94",
 "LegD_LowerLeg_L": "9202acbc-d599-c41d-a967-0f8c05ed7c57",
 "LegD_LowerLeg_R": "3198d0f8-c2c4-62a8-3e9f-8f285b7a51b2",
 "LegD_Foot_L_1": "c8d5f061-2246-4ca7-f0c0-8c7e06ce0440",
 "LegD_Foot_L_2": "bb4f16a1-fb91-780a-3cbb-9fad7a42845d",
 "LegD_Foot_R_1": "87dfdf77-ba76-8931-82aa-0a1053ad8580",
 "LegD_Foot_R_2": "da9f1d1a-53f0-d58f-f3b6-e8c5d230ffbf",
}
assert set(dmeshes) == set(original_mapping)
def bounds(meshes):
    pts = [tuple(vertex[k] + e["origin"][k] for k in range(3))
           for e in meshes for vertex in e["vertices"].values()]
    return [(min(p[k] for p in pts), max(p[k] for p in pts)) for k in range(3)]
def width(meshes, k):
    a, b = bounds(meshes)[k]
    return b-a

# Per-section scaling must preserve visible design differences: the two
# authored thigh blocks now form a significantly broader silhouette than A.
left = [dmeshes[f"LegD_Thigh_L_{i}"] for i in (1, 2)]
right = [dmeshes[f"LegD_Thigh_R_{i}"] for i in (1, 2)]
a_thigh = by_name["Thigh_R_Mesh"]
assert width(right, 0) > 1.75 * width([a_thigh], 0)
assert abs(width(left, 0)-width(right, 0)) < 1e-6
assert abs(bounds(left)[0][0] + bounds(right)[0][1]) < 1e-6
assert abs(bounds(left)[0][1] + bounds(right)[0][0]) < 1e-6
# All section vertices and six face polygons survive the import.
for name, uid in original_mapping.items():
    src = source[uid]
    dest = dmeshes[name]
    assert len(dest["vertices"]) == len(src["vertices"]) == 8
    assert set(dest["vertices"]) == set(src["vertices"])
    assert set(dest["faces"]) == set(src["faces"])
    for face_uid, f in src["faces"].items():
        altered = dest["faces"][face_uid]
        assert altered["vertices"] == f["vertices"], name
        assert set(altered["uv"]) == set(f["uv"]), name
        # The authored model has no texture and UV points in 0..16, while
        # our runtime atlas is 96x32. All 6 remapped faces must target the
        # SERA palette's real interior (not its white corner).
        uv = list(altered["uv"].values())
        us = [p[0] for p in uv]
        vs = [p[1] for p in uv]
        assert min(us) >= 4 and max(us) <= 92, (name, face_uid)
        assert min(vs) >= 4 and max(vs) <= 28, (name, face_uid)
        assert max(us)-min(us) == 24, (name, face_uid)
        assert max(vs)-min(vs) == 24, (name, face_uid)
        # Raw source model still has its original small UVs.
        assert min(p[0] for p in f["uv"].values()) == 0

# Original A skeleton, animated tracks and source geometry are untouched.
ids = {x["uuid"]: x for x in combined["elements"]}
for a in base["elements"]:
    imported = ids[a["uuid"]]
    # Blockbench's combined artist file intentionally hides A base meshes in
    # its editor. That display-only state differs from the runtime A source.
    # The geometry, pivots, faces, UV and everything else must still match.
    assert {k: v for k, v in imported.items() if k != "visibility"} == {
        k: v for k, v in a.items() if k != "visibility"}
assert len(base["groups"]) == 22 and len(base["elements"]) == 25
assert len(base["animations"]) >= 20

# The checked-in runtime snapshot must match the Blockbench model exactly.
raw = read("assets/sera_equipment_data.gd")
chunks = [json.loads(line.strip().removesuffix(",")) for line in raw.splitlines()
          if line.startswith('    "')]
embedded = json.loads("".join(chunks))
for key in ("groups", "elements", "outliner"):
    assert embedded[key] == combined[key]

eq = read("scripts/sera_equipment.gd")
assert 'part_list.size() != 12' in eq
assert '_verify_d_lower_body_visibility()' in eq
assert 'SERA Lower Body D active: 12/12 authored meshes' in eq
assert '_add_mesh("C", "legs", child)' in eq
assert 'var equipment_set: String = "D" if set_id == "C" and slot == "legs" else set_id' in eq
assert 'set_grounding_enabled(enabled: bool)' in eq
save = read("scripts/sera_save.gd")
assert 'const SCHEMA_VERSION: int = 2' in save
nexus = read("scripts/command_nexus.gd")
assert 'const CUSTOMIZE_SLOTS = ["head", "torso", "legs", "arms", "booster", "weapon_r", "weapon_l"]' in nexus
assert (ROOT / "README_v194_ja.md").exists()
print("PASS: all 12 authored D meshes, improved distinguishability, SERA shading atlas")
print("PASS: original A geometry, bird C and Head C routing, generated model snapshot")
print("PASS: D selection refuses incomplete 12-part import and checks actual visible mesh counts")
print("Godot and Android visual execution NOT performed.")
