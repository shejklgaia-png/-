#!/usr/bin/env python3
"""v345: author pose, independent boss rig, Android snapshot and deployment contract."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
def read(path):
    return (root / path).read_text(encoding="utf-8")
def doc(path):
    return json.loads(read(path))

source = doc("models/storage/ボステスト (2).bbmodel")
boss = doc("models/bosses/Bittaran.bbmodel")
assert boss["name"] == "ビットタラン"
for key in ("groups", "elements", "outliner", "textures"):
    assert boss[key] == source[key], "Authored Bittaran rig changed: " + key
assert len(boss["groups"]) == len(boss["elements"]) == 14
assert [a["name"] for a in boss["animations"]] == ["Wait", "Idle", "Turn", "Approach"]
assert boss["animations"][0] == source["animations"][0], "Authored Wait stance lost"
group_ids = {g["uuid"] for g in boss["groups"]}
all_ids = []
for clip in boss["animations"]:
    assert set(clip["animators"]).issubset(group_ids)
    for key in (k for tr in clip["animators"].values() for k in tr["keyframes"]):
        all_ids.append(key["uuid"])
assert len(all_ids) == len(set(all_ids))
for clip, duration in zip(boss["animations"][1:], (2.4, 1.8, 2.8)):
    assert clip["loop"] == "loop"
    assert abs(clip["length"] - duration) < 1e-6
    assert len(clip["animators"]) == 10
    assert sum(len(t["keyframes"]) for t in clip["animators"].values()) == 90
assert all(any(g["name"] == name for g in boss["groups"])
           for name in ("FrontFoot_R", "FrontFoot_L", "RearFoot_R", "RearFoot_L"))

embedded = read("assets/bittaran_data.gd")
match = re.search(r'^const MODEL_JSON: String = (".*")$', embedded, re.MULTILINE)
assert match and json.loads(match.group(1)) == read("models/bosses/Bittaran.bbmodel")
manifest = doc("models/manifest.json")
assert manifest["bosses"]["bittaran"] == "models/bosses/Bittaran.bbmodel"
rig = read("scripts/bittaran_rig.gd")
ai = read("scripts/bittaran_ai.gd")
nexus = read("scripts/command_nexus.gd")
battle = read("scripts/bittaran_battle.gd")
scene = read("scenes/bittaran_battle.tscn")
assert 'const VISION_TOTAL_DEGREES: float = 100.0' in ai
assert 'const VISION_HALF_DEGREES: float = 50.0' in ai
assert 'const APPROACH_SPEED_MPS: float = 0.72' in ai
assert 'const STATIONARY_TURN_DEG_PER_SEC: float = 34.0' in ai
assert 'const MOVING_TURN_DEG_PER_SEC: float = 22.0' in ai
assert 'const STOP_DISTANCE_METERS: float = 7.8' in ai
assert 'func _tap_deployment_boss(' in nexus
assert 'func _start_boss_scene(' in nexus
assert 'res://scenes/bittaran_battle.tscn' in nexus
assert 'res://scripts/bittaran_battle.gd' in scene
assert 'extends "res://scripts/main.gd"' in battle
assert 'super._build_target()' in battle
assert 'target_mesh.visible = false' in battle
assert 'func _tick_target_respawn(' in battle
assert 'animations.has("Approach")' in rig
print("PASS v345 Bittaran authored pose, independent motions, gate, AI and embed")
