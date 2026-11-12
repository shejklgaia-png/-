#!/usr/bin/env python3
"""SERA v276: authored Katana asset, hierarchy, clip and embedded-model regression."""
import base64
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
src = json.loads((root / "assets/sera_source.json").read_text())
author = json.loads((root / "models/storage/SERA_BOOSTER_allテスト (9) (2) (2).bbmodel").read_text())
names = {"Katana_r_nukimi", "Katana_l", "Katana_l2", "Katana_l3", "Katana_r_saya"}
groups = {g["uuid"]: g for g in src["groups"]}
meshes = {e["uuid"]: e for e in src["elements"]}
for g in author["groups"]:
    if g["name"] in names:
        assert groups[g["uuid"]] == g, g["name"]
assert len([g for g in author["groups"] if g["name"] in names]) == 5
uids = ("aaad34b8-6ed3-83ed-0dfc-a1a72afc1091", "43ad14e7-205f-4c5f-28c9-24c32166b1cc",
        "8c4e7bcf-830f-5eb8-24e7-154d6cf802ab", "487e802d-e890-b52e-77e3-7819eefc1f33",
        "2e7b8175-8aea-6b7b-72ae-62db3fcf4535", "a1cea279-2054-7153-0fa0-a24318563d55",
        "41e9a281-0e29-9a29-a911-bfa105bc32f3")
for uid in uids:
    assert meshes[uid] == next(x for x in author["elements"] if x["uuid"] == uid)
clip = next(a for a in author["animations"] if a["name"] == "Melee_katana")
assert next(a for a in src["animations"] if a["name"] == "Melee_katana") == clip
assert clip["length"] == 0.5
parents = {}
def visit(node, parent=""):
    if isinstance(node, dict):
        parents[node["uuid"]] = parent
        for c in node.get("children", []):
            visit(c, node["uuid"])
for n in src["outliner"]:
    visit(n)
names_to_id = {g["name"]: g["uuid"] for g in src["groups"]}
assert parents[names_to_id["Katana_r_nukimi"]] == names_to_id["Hand_R"]
assert parents[names_to_id["Katana_l"]] == names_to_id["Forearm_L"]
assert parents[names_to_id["Katana_r_saya"]] == names_to_id["Katana_l3"]
raw = (root / "assets/sera_source.json").read_bytes()
parts = re.findall(r'    "([A-Za-z0-9+/=]+)",', (root / "assets/sera_data.gd").read_text())
assert base64.b64decode("".join(parts)) == raw
e = (root / "scripts/sera_equipment.gd").read_text()
r = (root / "scripts/sera_rig.gd").read_text()
m = (root / "scripts/main.gd").read_text()
assert "3.0 / 24.0" in e and "katana_saya_meshes" in e
assert 'const KATANA_CLIP: String = "Melee_katana"' in r
assert "_active_strike_clip" in m
version = re.search(r'config/name="SERA v([0-9]+)"', (root / "project.godot").read_text())
assert version and int(version.group(1)) >= 276
print("V276_KATANA_STATIC_PASS: 5 authored pivots, 7 meshes, 0.5s clip, exact embed")
