#!/usr/bin/env python3
"""SERA v309: the photographed right STEP is copied exactly from 9.2.2."""
from pathlib import Path
import base64
import json
import re

ROOT = Path(__file__).resolve().parents[1]
def text(path): return (ROOT / path).read_text(encoding="utf-8")
def load(path): return json.loads(text(path))
def clip(data, name):
    choices = [item for item in data["animations"] if item["name"] == name]
    assert len(choices) == 1, (name, len(choices))
    return choices[0]

version = re.search(r'^config/name="SERA v(\d+)"$', text("project.godot"), re.M)
assert version is not None and int(version.group(1)) >= 309
selected = load("models/storage/SERA_BOOSTER_allテスト (9) (2) (2).bbmodel")
live = load("assets/sera_source.json")
model = load("models/SERA_BOOSTER_allテスト.bbmodel")

right = clip(selected,"Step_R")
assert clip(live,"Step_R") == right, "Runtime Step_R must be identical to 9.2.2"
assert clip(model,"Step_R") == right, "Integrated Blockbench Step_R must be identical to 9.2.2"
assert right["uuid"] == "89d9039b-e40c-6cce-f680-aac585192be8"
assert right["length"] == 0 and right["loop"] == "once"

groups = {g["uuid"]:g["name"] for g in selected["groups"]}
keys = [(groups.get(uid,uid),key)
        for uid,anim in right["animators"].items() for key in anim.get("keyframes", [])]
assert len(keys) == 19
assert sum(key["channel"] == "rotation" for _,key in keys) == 18
assert sum(key["channel"] == "position" for _,key in keys) == 1
assert all(float(key["time"]) == 0.0 for _,key in keys)
for bone, angles in {
    "Waist":("-42.5","-70","0"),
    "Head":("35.3614","71.1021","40.2028"),
}.items():
    rotations = [key["data_points"][0] for name,key in keys
                 if name == bone and key["channel"] == "rotation"]
    assert len(rotations) == 1
    assert tuple(rotations[0][axis] for axis in ("x","y","z")) == angles

assert [a["name"] for a in live["animations"]].count("Step_R") == 1
assert [a["name"] for a in model["animations"]].count("Step_R") == 1
for name in ("Step_L","Frontstep","Backstep"):
    assert clip(live,name)["name"] == name
rig = text("scripts/sera_rig.gd")
main = text("scripts/main.gd")
assert 'const STEP_RIGHT_CLIP: String = "Step_R"' in rig
assert 'STEP_RIGHT_CLIP if direction.x >= 0.0 else STEP_LEFT_CLIP' in rig
assert 'rig.call("start_omni_step", pose_direction)' in main

data = (ROOT/"assets/sera_source.json").read_bytes()
parts = re.findall(r'^    "([A-Za-z0-9+/=]+)",$', text("assets/sera_data.gd"), re.M)
assert parts and base64.b64decode("".join(parts),validate=True) == data
print("PASS v309: exact 9.2.2 Step_R UUID and all 19 keys; APK data, same playback path")
