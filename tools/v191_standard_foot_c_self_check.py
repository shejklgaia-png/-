#!/usr/bin/env python3
"""v191: Foot C custom authoring source, standard-bone mapping and snapshot."""
from __future__ import annotations
from pathlib import Path
import json
import math
import re

ROOT = Path(__file__).resolve().parents[1]
project = (ROOT / "project.godot").read_text(encoding="utf-8")
if not re.search(r'^config/name="SERA v191"$', project, re.M):
    print("SKIP: v191-only foot import test")
    raise SystemExit(0)

def model(name):
    return json.loads((ROOT / name).read_text(encoding="utf-8"))

combined = model("models/SERA_BOOSTER_allテスト.bbmodel")
original = model("models/storage/足C.bbmodel")
canonical = model("assets/sera_source.json")
by_name = {g["name"]: g for g in combined["groups"]}
by_uuid = {g["uuid"]: g for g in combined["groups"]}
meshes = {e["uuid"]: e for e in combined["elements"]}
source_meshes = {e["uuid"]: e for e in original["elements"]}
source_groups = {g["uuid"]: g for g in original["groups"]}
canonical_meshes = {e["name"]: e for e in canonical["elements"]}
canonical_groups = {g["name"]: g for g in canonical["groups"]}

assert len(combined["groups"]) == 54
assert len(combined["elements"]) == 61
assert len(combined["animations"]) == 23
assert len(canonical["groups"]) == 22 and len(canonical["elements"]) == 25
assert len(set(by_uuid) | set(meshes)) == len(by_uuid) + len(meshes)

# A's geometry, pivots and topology must be identical to the canonical
# gameplay rig. The Blockbench authoring file intentionally has different
# editor visibility/selection flags and extra artist-edited animation tracks.
IGNORED_GROUP_METADATA = {"visibility", "isOpen", "primary_selected", "selected"}
def without_editor_state(obj, ignored):
    return {k: v for k, v in obj.items() if k not in ignored}
for base in canonical["groups"]:
    actual = by_uuid[base["uuid"]]
    assert without_editor_state(actual, IGNORED_GROUP_METADATA) == (
        without_editor_state(base, IGNORED_GROUP_METADATA))
for base in canonical["elements"]:
    actual = meshes[base["uuid"]]
    assert without_editor_state(actual, {"visibility", "selected"}) == (
        without_editor_state(base, {"visibility", "selected"}))
# Older authoring clips intentionally contain artist-authored changes relative
# to canonical combat. They are not overwritten by this foot-only import.
assert len(combined["animations"]) == 23
assert {"Wait_motion", "run_front_original", "run_right",
        "run_Left", "NEXUS_pose", "ジャンプ"}.issubset(
            {a["name"] for a in combined["animations"]})
# The authoring asset intentionally lacks run_back; gameplay has that clip
# in assets/sera_source.json. Foot C does not change either source.

# C is a character root already hosting Head C; preserve head geometry/pivots.
root = next(n for n in combined["outliner"] if by_uuid.get(n.get("uuid"), {}).get("name") == "Waist3")
assert len(combined["outliner"]) == 4
assert by_name["Neck3"]["origin"] == [0, 23, 0]
assert by_name["Head3"]["origin"] == [0, 25.976, 1.056]
assert any(e["name"] == "HeadC_Head_torus" for e in meshes.values())

# A compatible full C lower body: six standard A-clone meshes (two hips,
# two thighs, two shins) with fresh IDs, plus two sole meshes on each foot.
c_names = {
    "Thigh_L3", "LowerLeg_L3", "Foot_L3",
    "Thigh_R3", "LowerLeg_R3", "Foot_R3"
}
assert c_names.issubset(by_name)
assert all(by_name[f"{part}_{side}3"]["origin"] ==
           canonical_groups[f"{part}_{side}"]["origin"]
           for part in ("Thigh", "LowerLeg", "Foot") for side in ("L", "R"))

def find_child(children, group_name):
    return next(c for c in children if isinstance(c, dict) and
                by_uuid[c["uuid"]]["name"] == group_name)
def get_meshes(children):
    return [meshes[id] for id in children if isinstance(id, str)]

assert len([e for e in get_meshes(root["children"]) if e["name"].startswith("FootC_Base_Waist")]) == 2
feet = {}
for side in ("L", "R"):
    thigh = find_child(root["children"], f"Thigh_{side}3")
    shin = find_child(thigh["children"], f"LowerLeg_{side}3")
    foot = find_child(shin["children"], f"Foot_{side}3")
    assert len(get_meshes(thigh["children"])) == 1
    assert len(get_meshes(shin["children"])) == 1
    feet[side] = get_meshes(foot["children"])
    assert len(feet[side]) == 2
    assert sorted(e["name"] for e in feet[side]) == [
        f"FootC_{side}_1", f"FootC_{side}_2"
    ]

# The authoring file calls both groups 'right foot'; group X establishes side.
src_root = next(n for n in original["outliner"] if source_groups[n["uuid"]]["name"] == "腰")
src_thigh = next(c for c in src_root["children"] if isinstance(c, dict) and
                 source_groups[c["uuid"]]["name"] == "右腿")
src_knee = next(c for c in src_thigh["children"] if isinstance(c, dict) and
                source_groups[c["uuid"]]["name"] == "右膝")
src_right = next(c for c in src_knee["children"] if isinstance(c, dict) and
                 source_groups[c["uuid"]]["name"] == "右足")
src_left = next(c for c in src_knee["children"] if isinstance(c, dict) and
                source_groups[c["uuid"]]["name"] == "右足2")
assert source_groups[src_right["uuid"]]["origin"][0] == 14.1
assert source_groups[src_left["uuid"]]["origin"][0] == -14.1
for side, entry in (("L", src_left), ("R", src_right)):
    for i, uid in enumerate(entry["children"]):
        old = source_meshes[uid]
        new = next(e for e in feet[side] if e["name"] == f"FootC_{side}_{i+1}")
        target_origin = canonical_groups[f"Foot_{side}"]["origin"]
        source_pivot = source_groups[entry["uuid"]]["origin"]
        expected_origin = [
            round(target_origin[0] + (old["origin"][0]-source_pivot[0])*.29, 7),
            round((old["origin"][1]-.2)*.57, 7),
            round(target_origin[2] + (old["origin"][2]-source_pivot[2])*.29, 7),
        ]
        assert new["origin"] == expected_origin
        assert new["faces"] == old["faces"], "face / UV data altered"
        assert new["rotation"] == old["rotation"]
        assert set(new["vertices"]) == set(old["vertices"])
        for point, vec in old["vertices"].items():
            assert new["vertices"][point] == [
                round(vec[0]*.29, 7),
                round(vec[1]*.57, 7),
                round(vec[2]*.29, 7),
            ]
        assert new["origin"][1] == 0

# Footprint is intentionally just 10-20% larger than default, not 2x.
default = canonical_meshes["Foot_R_Mesh"]
def extent(mesh, i):
    vertices = list(mesh["vertices"].values())
    return max(v[i] for v in vertices) - min(v[i] for v in vertices)
ratio_x = (16 * .29) / extent(default, 0)
ratio_y = (8 * .57) / extent(default, 1)
ratio_z = (30.9 * .29) / extent(default, 2)
assert 1.10 < ratio_x < 1.20
assert 1.10 < ratio_y < 1.20
assert 1.10 < ratio_z < 1.20

# Generated equipment data still matches the full authoring source exactly.
raw = (ROOT / "assets/sera_equipment_data.gd").read_text(encoding="utf-8")
segments = [json.loads(line.strip().rstrip(",")) for line in raw.splitlines()
            if line.startswith("    \"")]
embedded = json.loads("".join(segments))
for key in ("groups", "elements", "outliner"):
    assert embedded[key] == combined[key], key

loader = (ROOT / "scripts/sera_equipment.gd").read_text(encoding="utf-8")
assert 'if set_id == "C" and str(piece.name).contains("HeadC_"):' in loader
assert 'if slot == "legs":' in loader
assert '_apply_legs_grounding(set_id)' in loader
assert 'func _cache_bind_foot_geometry()' in loader
assert (ROOT / "README_v191_ja.md").is_file()
print("PASS: 6 new standard C leg joints, 10 C leg meshes, 4 scaled feet, A motion & C head intact")
print("PASS: equipment snapshot round-trip, side/pivot/UV and contact-grounding hook")
print("Godot/Android actual rendering and sound remain UNTESTED")
