#!/usr/bin/env python3
"""SERA v211: integrate the user's authored Frontstep into real forward/diagonal STEP."""
from __future__ import annotations

import base64
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

project = read("project.godot")
assert 'config/name="SERA v211"' in project
source_bytes = (ROOT / "assets/sera_source.json").read_bytes()
source = json.loads(source_bytes)
model = json.loads(read("models/SERA_BOOSTER_allテスト.bbmodel"))
user = json.loads(read("models/storage/SERA_BOOSTER_allテスト (5).bbmodel"))
original_model = json.loads(read("models/storage/SERA_BOOSTER_allテスト (4).bbmodel"))
rig = read("scripts/sera_rig.gd")
main = read("scripts/main.gd")

# Only the new animation was added. All other consolidated Blockbench clips,
# authored pivot/mesh geometry and equipment groups remain unchanged.
source_clips = {a["name"]: a for a in source["animations"]}
model_clips = {a["name"]: a for a in model["animations"]}
assert len(source_clips) == len(source["animations"]) == 23
assert len(model_clips) == len(model["animations"]) == 24
assert model["animations"][:len(original_model["animations"])] == original_model["animations"]
# Consolidated model diverged from the old authored (4) source in v206 to
# correct nozzle pivots and geometry. Its existing group and mesh counts must
# remain intact, but exact equality to that older source is not expected.
assert len(model["groups"]) == len(original_model["groups"]) == 57
assert len(model["elements"]) == len(original_model["elements"]) == 68
assert len(model["outliner"]) == 4
assert model["textures"] == original_model["textures"]
# The live A source already has Jump and run_back while the equipment model
# retains separate historical names. Compare only the newly imported clip.
assert source_clips["Frontstep"]["name"] == model_clips["Frontstep"]["name"]
assert source["groups"] and len(source["groups"]) == 22
assert len(source["elements"]) == 25

# Frontstep is a single authored Blockbench pose, not a copied BOOST frame.
user_clips = [a for a in user["animations"] if a["name"] == "Frontstep"]
assert len(user_clips) == 1
front = user_clips[0]
assert front["loop"] == "loop" and float(front["length"]) == 0.0
assert model_clips["Frontstep"] == front
allowed = {g["uuid"] for g in source["groups"]}
expected_animators = {uid: anim for uid,anim in front["animators"].items() if uid in allowed}
assert source_clips["Frontstep"]["animators"] == expected_animators
assert set(source_clips["Frontstep"]["animators"]) == allowed
frames = [frame for a in expected_animators.values() for frame in a.get("keyframes", [])]
assert len(frames) >= 18 and all(float(frame["time"]) == 0.0 for frame in frames)
assert source_clips["Frontstep"] != source_clips["Boost_front"]

# Export data must match the exact JSON bytes used in Android APK builds.
parts = re.findall(r'^    "([A-Za-z0-9+/=]+)",$', read("assets/sera_data.gd"), re.M)
assert parts and base64.b64decode("".join(parts), validate=True) == source_bytes

# Frontstep is now the cardinal forward pose. No change to BOOST, BACK or
# lateral STEP tracks; diagonals still blend via the continuous 360° direction.
assert 'const STEP_FORWARD_CLIP: String = "Frontstep"' in rig
assert 'animations.has(STEP_FORWARD_CLIP)' in rig
blend = rig.split("func _blended_directional_step_pose(", 1)[1].split("func start_omni_step(",1)[0]
assert '_sample_step_clip_pose(STEP_FORWARD_CLIP, uid, 0.0) if direction.y < 0.0' in blend
assert '_sample_step_clip_pose(STEP_BACK_CLIP, uid, 0.0)' in blend
assert 'STEP_RIGHT_CLIP if direction.x >= 0.0 else STEP_LEFT_CLIP' in blend
assert 'atan2(absf(direction.x), absf(direction.y)) / (PI * 0.5)' in blend
assert '.slerp(' in blend and '.lerp(' in blend
assert '_sample_boost_pose(BOOST_CLIP, uid) if direction.y < 0.0' not in blend
assert 'const BOOST_CLIP: String = "Boost_front"' in rig
assert 'directional_step_vector = direction.normalized()' in rig
assert 'state_label.text = "STEP FORWARD  |  Frontstep"' in main
assert 'rig.call("start_omni_step", direction)' in main
assert 'const STEP_MIN_ARC_LENGTH: float = 2.0' in main
assert 'const STEP_MAX_ARC_LENGTH: float = 4.0' in main

print("PASS SERA v211: user Frontstep authored tracks integrated; originals preserved")
print("PASS: exact APK embed and forward/diagonal STEP wiring, other axes unchanged")
print("Godot Android graphics and touch-runtime behavior not verified")
