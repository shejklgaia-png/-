#!/usr/bin/env python3
"""v316: canonical Blockbench source, pivots, clips and export snapshots."""
import base64
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def read(path):
    return (ROOT / path).read_text(encoding="utf-8")
def doc(path):
    return json.loads(read(path))
def unpack(path):
    parts = [json.loads(s.strip().removesuffix(","))
             for s in read(path).splitlines() if s.startswith('    "')]
    return json.loads("".join(parts))

manifest = doc("models/manifest.json")
assert manifest["schema"] == 1
paths = [manifest["body_rig"], *manifest["variants"].values(), *manifest["parts"].values()]
assert all((ROOT / p).is_file() for p in paths)
assert all(len(set(g["uuid"] for g in doc(p)["groups"])) == len(doc(p)["groups"])
           for p in set(paths))
standard = doc("models/core/Standard.bbmodel")
legacy = doc("models/SERA_BOOSTER_allテスト.bbmodel")
bird = doc("models/core/BirdLeg.bbmodel")
katana = doc("models/core/Katana.bbmodel")
equipment = doc("models/core/Equipment.bbmodel")
head = doc("models/storage/Head_C.bbmodel")
legs = doc("models/storage/LowerBody_D.bbmodel")
full_bird = doc("models/storage/SERA_BIRD_LEGS_MIRROR_EDIT.bbmodel")
full_katana = doc("models/storage/SERA_BOOSTER_allテスト.bbmodel")

# No edited/intermediate model may silently replace user authored tracks.
assert read("assets/sera_source.json") == read("models/core/Standard.bbmodel")
b64 = "".join(re.findall(r'^    "([A-Za-z0-9+/=]+)",$',read("assets/sera_data.gd"),re.M))
assert base64.b64decode(b64).decode("utf-8") == read("models/core/Standard.bbmodel")
assert len(standard["animations"]) >= 28
standard_clips = {c["name"]: c for c in standard["animations"]}
assert standard_clips["NEXUS_pose"] == next(a for a in legacy["animations"] if a["name"] == "NEXUS_pose")
assert standard_clips["Step_R"] == next(a for a in doc("assets/sera_source.json")["animations"] if a["name"] == "Step_R")
assert len(bird["elements"]) == 10 and len(bird["groups"]) == 7
assert len(bird["animations"]) == 23
bird_uids = {g["uuid"] for g in bird["groups"] if g["name"].startswith("Bird_")}
assert len(bird_uids) == 6
assert all(set(a["animators"]).issubset(bird_uids) for a in bird["animations"])
full_clips = {a["name"]: a for a in full_bird["animations"]}
for a in bird["animations"]:
    for uid, tracks in a["animators"].items():
        assert tracks == full_clips[a["name"]]["animators"][uid]
assert len(equipment["animations"]) == 0
assert len(equipment["outliner"]) == 2
assert len(equipment["groups"]) == 45 and len(equipment["elements"]) == 53
assert len(head["elements"]) == 2 and len(legs["elements"]) == 12
assert len(katana["animations"]) == 2
katana_clips = {a["name"]:a for a in katana["animations"]}
assert set(katana_clips) == {"Melee_katana","Melee_katana2"}
assert katana_clips["Melee_katana"] == standard_clips["Melee_katana"]
assert katana_clips["Melee_katana2"] == next(a for a in full_katana["animations"] if a["name"]=="Melee_katana2")
for path, model in [
    ("assets/sera_equipment_data.gd", equipment),
    ("assets/sera_head_c_data.gd", head),
    ("assets/sera_lower_body_d_data.gd", legs),
]:
    payload = unpack(path)
    assert payload == {key:model[key] for key in ("groups","elements","outliner")}, path
katana_embedded = unpack("assets/sera_katana_data.gd")
assert {a["name"]: a for a in katana_embedded["animations"]} == katana_clips
assert 'KATANA_EMBEDDED.get_json()' in read("scripts/sera_rig.gd")
bird_embedded = unpack("assets/sera_bird_data.gd")
assert len(bird_embedded["groups"]) == 6 and len(bird_embedded["elements"]) == 10
assert len(bird_embedded["animations"]) == 23
for clip in bird_embedded["animations"]:
    assert clip["animators"] == next(a["animators"] for a in bird["animations"] if a["name"]==clip["name"])
rig = read("scripts/sera_rig.gd")
equip = read("scripts/sera_equipment.gd")
nexus = read("scripts/command_nexus.gd")
for target in ("models/core/Standard.bbmodel", "models/core/BirdLeg.bbmodel",
               "models/core/Katana.bbmodel"):
    assert f'res://{target}' in rig
for target in ("models/core/Equipment.bbmodel", "models/storage/Head_C.bbmodel",
               "models/storage/LowerBody_D.bbmodel"):
    assert f'res://{target}' in equip
assert "NEXUS_POSE_SOURCES" not in nexus and 'rig.get("animations")' in nexus
assert '_install_head_c()' in equip and "HEAD_C_EMBEDDED" in equip
for forbidden in ("res://models/storage/SERA_BOOSTER", "res://models/storage/SERA_BIRD",
                  'res://models/SERA_BOOSTER_all'):
    assert forbidden not in rig + equip + nexus
print("V316_CANONICAL_MODEL_SOURCES_PASS")
