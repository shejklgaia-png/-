#!/usr/bin/env python3
"""Check updated standard-skeleton C author source and isolated runtime-ready D asset."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(relative):
    return json.loads((ROOT / relative).read_text(encoding="utf-8"))

raw = read("models/storage/足C (1).bbmodel")
previous = read("models/storage/足C.bbmodel")
authored = read("models/storage/SERA_LEGS_C_AUTHOR_NORMALIZED.bbmodel")
ready = read("models/storage/SERA_LOWER_BODY_D_STANDARD_READY.bbmodel")
integrated = read("models/SERA_BOOSTER_allテスト.bbmodel")

author_names = [
    "LegC_Waist_Upper", "LegC_Waist_Lower",
    "LegC_Thigh_R_1", "LegC_Thigh_R_2",
    "LegC_LowerLeg_L", "LegC_Thigh_L_1",
    "LegC_LowerLeg_R", "LegC_Thigh_L_2",
    "LegC_Foot_R_1", "LegC_Foot_L_1",
    "LegC_Foot_R_2", "LegC_Foot_L_2",
]

def tree_paths(model):
    groups = {g["uuid"]: g for g in model["groups"]}
    meshes = {e["uuid"]: e for e in model["elements"]}
    assert len(groups) == len(model["groups"]), "Duplicate joint UUID"
    assert len(meshes) == len(model["elements"]), "Duplicate mesh UUID"
    paths = {}
    def visit(entry, chain):
        if isinstance(entry, str):
            assert entry in meshes, "Mesh UUID missing"
            assert entry not in paths, "Mesh referenced twice"
            paths[entry] = tuple(chain)
            return
        assert entry["uuid"] in groups, "Group UUID missing"
        for child in entry.get("children", []):
            visit(child, [*chain, groups[entry["uuid"]]["name"]])
    for entry in model["outliner"]:
        visit(entry, [])
    assert set(paths) == set(meshes), "Unused mesh left in asset"
    return groups, meshes, paths

assert len(raw["elements"]) == len(authored["elements"]) == len(ready["elements"]) == 12
assert len(authored["groups"]) == len(ready["groups"]) == 7
raw_by_id = {e["uuid"]: e for e in raw["elements"]}
old_by_id = {e["uuid"]: e for e in previous["elements"]}
author_by_id = {e["uuid"]: e for e in authored["elements"]}
assert raw_by_id.keys() == author_by_id.keys() == old_by_id.keys()

# A repositioned mesh origin is allowed only if global vertex geometry stays
# at the same positions. The user also changed some source author pivots.
for i, (old, new) in enumerate(zip(previous["elements"], raw["elements"])):
    assert old["uuid"] == new["uuid"]
    for uid, xyz in old["vertices"].items():
        for axis in range(3):
            a = xyz[axis] + old["origin"][axis]
            b = new["vertices"][uid][axis] + new["origin"][axis]
            assert abs(a - b) < 1e-5, ("Changed world vertex", i, uid, axis)
    assert old["faces"] == new["faces"], "Authored UV or face changed"

for i, raw_mesh in enumerate(raw["elements"]):
    part = author_by_id[raw_mesh["uuid"]]
    assert part["name"] == author_names[i]
    # Only mesh names were changed. No faces, vertex coordinates, UV, materials,
    # local mesh origins or rotations were touched in the normalized author file.
    for key in raw_mesh.keys():
        if key != "name":
            assert part[key] == raw_mesh[key], (part["name"], key)

ag, ae, ap = tree_paths(authored)
assert len(ag) == 7
assert {g["name"] for g in ag.values()} == {
    "Waist", "Thigh_R", "LowerLeg_R", "Foot_R",
    "Thigh_L", "LowerLeg_L", "Foot_L"
}
paths_by_name = {ae[uid]["name"]: path for uid, path in ap.items()}
for name, path in paths_by_name.items():
    if "_Waist_" in name:
        assert path == ("Waist",), (name, path)
    elif "_Thigh_R_" in name:
        assert path == ("Waist", "Thigh_R"), (name, path)
    elif "_Thigh_L_" in name:
        assert path == ("Waist", "Thigh_L"), (name, path)
    elif "_LowerLeg_R" in name:
        assert path == ("Waist", "Thigh_R", "LowerLeg_R"), (name, path)
    elif "_LowerLeg_L" in name:
        assert path == ("Waist", "Thigh_L", "LowerLeg_L"), (name, path)
    elif "_Foot_R_" in name:
        assert path == ("Waist", "Thigh_R", "LowerLeg_R", "Foot_R"), (name, path)
    elif "_Foot_L_" in name:
        assert path == ("Waist", "Thigh_L", "LowerLeg_L", "Foot_L"), (name, path)
    else:
        raise AssertionError("Unknown mesh part: " + name)

pivots = {g["name"]: g["origin"] for g in ag.values()}
for part in ("Thigh", "LowerLeg", "Foot"):
    r = pivots[f"{part}_R"]
    l = pivots[f"{part}_L"]
    assert l == [-r[0], r[1], r[2]], (part, l, r)
assert pivots["Waist"] == [0, 46.3, 0]
assert pivots["Foot_L"] == [-14.1, 13.7, 0]

rg, re, rp = tree_paths(ready)
ig, ie, ip = tree_paths(integrated)
assert len(rg) == 7 and len(re) == 12
assert all(name.startswith("LegD_") for name in (x["name"] for x in re.values()))
assert not ready.get("animations"), "Standard rig should reuse shared animations"
for uid, group in rg.items():
    assert group == ig[uid], ("Altered standard A joint", group["name"])
for uid, mesh in re.items():
    assert mesh == ie[uid], ("Unexpected runtime geometry modification", mesh["name"])
    assert rp[uid] == ip[uid], ("Runtime bone mismatch", mesh["name"])
assert {group["name"] for group in rg.values()} == {
    "Waist3", "Thigh_R3", "LowerLeg_R3", "Foot_R3",
    "Thigh_L3", "LowerLeg_L3", "Foot_L3"
}
assert {m["name"].replace("LegD_", "LegC_") for m in re.values()} == set(author_names)
for a, b in zip([0, 1, 2, 3, 5, 7, 6, 4, 8, 10, 9, 11], [
    "Waist_Upper", "Waist_Lower", "Thigh_R_1", "Thigh_R_2",
    "Thigh_L_1", "Thigh_L_2", "LowerLeg_R", "LowerLeg_L",
    "Foot_R_1", "Foot_R_2", "Foot_L_1", "Foot_L_2",
]):
    source_mesh = raw["elements"][a]
    target_mesh = next(e for e in re.values() if e["name"] == "LegD_" + b)
    assert source_mesh["faces"] == target_mesh["faces"], b
    assert set(source_mesh["vertices"]) == set(target_mesh["vertices"]), b

print("PASS: latest user C input identified, global authored geometry and UV preserved")
print("PASS: seven correctly mirrored author joints, twelve uniquely named mesh parts")
print("PASS: isolated D runtime asset uses exact standard joints and 12 integrated meshes")
print("Godot/Xperia runtime rendering NOT tested")
