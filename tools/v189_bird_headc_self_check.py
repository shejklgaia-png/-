#!/usr/bin/env python3
"""v189 bird legs D + Head C corrected pivots (static integration regression)."""
from __future__ import annotations
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
version = (ROOT / "project.godot").read_text(encoding="utf-8")
if not re.search(r'^config/name="SERA v189"$', version, re.M):
    print("SKIP: v189-specific integration test")
    raise SystemExit(0)

def read_json(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))

def embedded_json(path):
    src = (ROOT / path).read_text(encoding="utf-8")
    assert "const PARTS = [" in src and "PackedStringArray(PARTS)" in src
    chunks = [json.loads(line.strip().rstrip(",")) for line in src.splitlines()
              if line.lstrip().startswith('"')]
    assert chunks
    return json.loads("".join(chunks))

base = read_json("assets/sera_source.json")
assert len(base["groups"]) == 22 and len(base["elements"]) == 25
bird = read_json("models/storage/SERA_BIRD_LEGS_MIRROR_EDIT.bbmodel")
embedded_bird = embedded_json("assets/sera_bird_data.gd")
full_groups = {g["uuid"]: g for g in bird["groups"]}
slim_groups = {g["uuid"]: g for g in embedded_bird["groups"]}
assert len(slim_groups) == 6
assert {g["name"] for g in slim_groups.values()} == {
    f"Bird_{part}_{side}" for part in ("Thigh", "LowerLeg", "Foot") for side in "LR"}
assert not (set(slim_groups) & {g["uuid"] for g in base["groups"]})
assert len(embedded_bird["elements"]) == 10
assert len(embedded_bird["outliner"]) == 4
assert len(embedded_bird["animations"]) == len(bird["animations"]) == 23
assert all(full_groups[uid] == group for uid, group in slim_groups.items())
for clip in embedded_bird["animations"]:
    assert set(clip["animators"]).issubset(slim_groups)
    authored = next(a for a in bird["animations"] if a["name"] == clip["name"])
    assert clip["animators"] == {
        uid: animator for uid, animator in authored.get("animators", {}).items() if uid in slim_groups}
nexus = next(a for a in embedded_bird["animations"] if a["name"] == "NEXUS_pose")
assert len(nexus["animators"]) == 6
assert all(len(animator.get("keyframes", [])) >= 1 for animator in nexus["animators"].values())
for part in ("Thigh", "LowerLeg", "Foot"):
    left = next(g for g in slim_groups.values() if g["name"] == f"Bird_{part}_L")
    right = next(g for g in slim_groups.values() if g["name"] == f"Bird_{part}_R")
    assert left["origin"][0] == -right["origin"][0]
    assert left["origin"][1:] == right["origin"][1:]

combined = read_json("models/SERA_BOOSTER_allテスト.bbmodel")
snapshot = embedded_json("assets/sera_equipment_data.gd")
assert all(snapshot[k] == combined[k] for k in ("groups", "elements", "outliner"))
assert len(combined["groups"]) == 48 and len(combined["elements"]) == 51
assert len(combined["animations"]) == 23
raw_head = read_json("models/storage/頭C (2) (1).bbmodel")
head_groups = {g["name"]: g for g in raw_head["groups"]}
combined_groups = {g["name"]: g for g in combined["groups"]}
assert combined_groups["Neck3"]["origin"] == [0, 23, 0]
def offset(pos):
    return [round(23 * (i == 1) + 0.48 * (pos[i] - head_groups["首"]["origin"][i]), 6)
            for i in range(3)]
assert combined_groups["Head3"]["origin"] == offset(head_groups["頭"]["origin"])
combined_mesh = {e["name"]: e for e in combined["elements"]}
original_mesh = {e["name"]: e for e in raw_head["elements"]}
for raw_name, target in [("torus", "HeadC_Head_torus"), ("tube", "HeadC_Neck_tube")]:
    src, dst = original_mesh[raw_name], combined_mesh[target]
    assert dst["origin"] == offset(src["origin"])
    assert dst["rotation"] == src["rotation"]
    assert len(dst["vertices"]) == len(src["vertices"])
    assert dst["faces"] == src["faces"]
    for uid, v in src["vertices"].items():
        assert all(abs(dst["vertices"][uid][i] - v[i] * 0.48) < 1e-6 for i in range(3))
def width(e):
    pts = list(e["vertices"].values())
    return max(p[0] for p in pts) - min(p[0] for p in pts)
assert abs(width(combined_mesh["HeadC_Head_torus"]) - 9.6) < 1e-4
assert abs(width(combined_mesh["HeadC_Neck_tube"]) - 5.952) < 1e-4
assert len({g["uuid"] for g in combined["groups"]} |
           {e["uuid"] for e in combined["elements"]}) == 99

rig = (ROOT / "scripts/sera_rig.gd").read_text(encoding="utf-8")
equipment = (ROOT / "scripts/sera_equipment.gd").read_text(encoding="utf-8")
nexus_script = (ROOT / "scripts/command_nexus.gd").read_text(encoding="utf-8")
assert "_install_bird_model()" in rig
assert "_merge_bird_animation_tracks()" in rig
assert 'head_c_proxy.quaternion = standard_head.quaternion' in rig
assert '_add_mesh("D", "legs", child)' in equipment
assert 'register_head_c_pivot' in equipment
assert "piece.quaternion = rig.call" in equipment
assert '"res://models/storage/SERA_BIRD_LEGS_MIRROR_EDIT.bbmodel"' in nexus_script
assert 'rig.call("_merge_bird_animation_tracks", pose_name)' in nexus_script
assert (ROOT / "README_v189_ja.md").is_file()
print("PASS: v189 6 bird bones, NEXUS pose, D slot, C authored pivots & data snapshots")
print("Static only: Godot/Android runtime not tested")
