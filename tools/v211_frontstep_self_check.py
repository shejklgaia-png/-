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
version = re.search(r'config/name="SERA v(\d+)"', project)
assert version is not None and int(version.group(1)) >= 211
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
assert len(source_clips) == len(source["animations"]) >= 25
assert {"Kick_l", "Kick_r"} <= set(source_clips)  # v265 adds the user-authored kick clips
assert len(model_clips) == len(model["animations"]) == 24
# v308 intentionally updates Step_R's Waist/Head while retaining its
# name and UUID. Every other historical clip remains unchanged.
for current, old in zip(model["animations"][:len(original_model["animations"])], original_model["animations"]):
    if old["name"] == "Step_R":
        assert current["uuid"] == old["uuid"] and current["name"] == old["name"]
        assert set(current["animators"]) == set(old["animators"])
        continue
    assert current == old
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
# A's 22 pivots / 25 elements remain intact; v276 adds 5 Katana pivots
# and 7 Katana meshes without changing the historical Frontstep.
base_groups = [g for g in source["groups"] if not g["name"].startswith("Katana")]
katana_ids = {
    "aaad34b8-6ed3-83ed-0dfc-a1a72afc1091",
    "43ad14e7-205f-4c5f-28c9-24c32166b1cc",
    "8c4e7bcf-830f-5eb8-24e7-154d6cf802ab",
    "487e802d-e890-b52e-77e3-7819eefc1f33",
    "2e7b8175-8aea-6b7b-72ae-62db3fcf4535",
    "a1cea279-2054-7153-0fa0-a24318563d55",
    "41e9a281-0e29-9a29-a911-bfa105bc32f3",
}
assert len(base_groups) == 22
assert len([x for x in source["elements"] if x["uuid"] not in katana_ids]) == 25

# Frontstep is a single authored Blockbench pose, not a copied BOOST frame.
user_clips = [a for a in user["animations"] if a["name"] == "Frontstep"]
assert len(user_clips) == 1
front = user_clips[0]
assert front["loop"] == "loop" and float(front["length"]) == 0.0
assert model_clips["Frontstep"] == front
allowed = {g["uuid"] for g in base_groups}
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
assert 'rig.call("start_omni_step", pose_direction)' in main
assert 'const STEP_MIN_ARC_LENGTH: float = 7.0' in main
assert 'const STEP_MAX_ARC_LENGTH: float = 7.0' in main

print("PASS SERA v211: user Frontstep authored tracks integrated; originals preserved")
print("PASS: exact APK embed and forward/diagonal STEP wiring, other axes unchanged")
print("Godot Android graphics and touch-runtime behavior not verified")
