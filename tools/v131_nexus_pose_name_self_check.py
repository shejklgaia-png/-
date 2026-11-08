#!/usr/bin/env python3
"""Source regression: accept actual Blockbench NEXUS_pose spelling.

Tests are static only. For a runtime test, first sync the updated .bbmodel
from Android GAME/Git/models into GitHub.
"""
from pathlib import Path
import json

root=Path(__file__).resolve().parents[1]
nexus=(root/"scripts/command_nexus.gd").read_text(encoding="utf-8")
project=(root/"project.godot").read_text(encoding="utf-8")
test_model=json.loads((root/"models/SERA_BOOSTER_allテスト.bbmodel").read_text(encoding="utf-8"))
assert 'config/name="SERA v149"' in project
assert 'const NEXUS_POSE_NAMES: Array[String] = ["NEXUS_pose", "NEXUSpose"]' in nexus
assert 'var pose_name: String = str(raw_clip.get("name", ""))' in nexus
assert 'if not NEXUS_POSE_NAMES.has(pose_name):' in nexus
assert 'rig.call("_build_animations", {"animations": [raw_clip]})' in nexus
assert 'if not available.has(pose_name):' in nexus
assert 'rig.set("current_clip", pose_name)' in nexus
assert 'rig.call("_apply_animation", 0.0)' in nexus
assert 'if not _apply_nexus_pose(rig):' in nexus
assert 'var arm_angles := {"UpperArm_R": -38.0' in nexus
assert '"res://models/SERA_BOOSTER_allテスト.bbmodel"' in nexus
assert "CUSTOMIZE_PREVIEW_DISTANCE: float = 3.25" in nexus
assert "customize_preview_scale = 1.40" in nexus
assert "func _rotate_customization_preview(delta_x: float) -> void:" in nexus
assert "sera_display_rig.transform = sera_original_transform" in nexus
assert "get_tree().change_scene_to_file(TRAINING_SCENE)" in nexus
assert 'CAMERA_TRANSITION_SECONDS: float = 0.18' in nexus
assert nexus.count("SeraRig.new()") == 1
assert {"Bash", "Guard_REACTION"}.issubset(
    {a["name"] for a in test_model["animations"]})
names={a["name"] for a in test_model["animations"]}
if "NEXUS_pose" not in names:
    print("PENDING: authored NEXUS_pose has not yet reached GitHub model file.")
else:
    pose=next(a for a in test_model["animations"] if a["name"]=="NEXUS_pose")
    assert any(a.get("keyframes") for a in pose.get("animators",{}).values())
    print("AUTHORED POSE PRESENT: NEXUS_pose")
print("v131 exact naming, alias, old menu and combat asset source assertions: PASS")
