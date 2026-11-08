#!/usr/bin/env python3
"""v130 larger SERA model preview and deferred user-authored NEXUSpose.

Static source/model checks only; Android Godot editor and APK remain untested.
"""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
s = (ROOT / "scripts/command_nexus.gd").read_text(encoding="utf-8")
project = (ROOT / "project.godot").read_text(encoding="utf-8")
display = json.loads((ROOT / "models/SERA_BOOSTER_allテスト.bbmodel").read_text(encoding="utf-8"))
canonical = json.loads((ROOT / "assets/sera_source.json").read_text(encoding="utf-8"))
rig = (ROOT / "scripts/sera_rig.gd").read_text(encoding="utf-8")

assert 'config/name="SERA v147"' in project
assert 'run/main_scene="res://scenes/launch_menu.tscn"' in project

# The previous two-pass 1.55x/1.05x cap suppressed enlargement.
assert "const CUSTOMIZE_PREVIEW_DISTANCE: float = 3.25" in s
assert "customize_preview_scale = 1.40" in s
assert "top_limit: float = size.y * 0.150" in s
assert "bottom_limit: float = size.y * 0.860" in s
assert "fit = clampf(fit, 0.15, 3.25)" in s
assert "fit = minf(fit, 1.55)" not in s
assert "fit = minf(fit, 1.05)" not in s
assert "func _customization_all_yaw_bounds()" in s
assert 'size.x * (placement.x + placement.y) + 18.0' in s
assert "right_limit: float = size.x * 0.970" in s
assert "CUSTOMIZE_PREVIEW_ROTATION_SAMPLES: int = 16" in s
assert "sera_display_rig.global_transform = cam.global_transform * Transform3D(" in s

# Only a display instance gets this user-created pose. Do not modify the
# combat SeraRig source or substitute a guessed animation for a missing one.
assert 'const NEXUS_POSE_NAMES: Array[String] = ["NEXUS_pose", "NEXUSpose"]' in s
assert '"res://models/SERA_BOOSTER_allテスト.bbmodel"' in s
assert '"res://models/SERA_BOOSTER_all.bbmodel"' in s
assert '"res://assets/sera_source.json"' in s
assert "func _apply_nexus_pose(rig: Node3D) -> bool:" in s
assert "FileAccess.file_exists(source_path)" in s
assert "FileAccess.get_file_as_string(source_path)" in s
assert 'if not NEXUS_POSE_NAMES.has(pose_name):' in s
assert 'rig.call("_build_animations", {"animations": [raw_clip]})' in s
assert 'rig.set("current_clip", pose_name)' in s
assert 'rig.call("_apply_animation", 0.0)' in s
assert "if not _apply_nexus_pose(rig):" in s
assert 'arm_angles := {"UpperArm_R": -38.0' in s
assert 'func _blockbench_rotation(angles: Vector3) -> Quaternion:' in rig
assert "animations[clip_name] = {" in rig

# The authored animation isn't in the current synced main model yet.
# Once synchronized, the next Godot scene startup discovers and applies it.
current_pose = next((a for a in display["animations"] if a["name"]=="NEXUSpose"),None)
if current_pose is None:
    print("PENDING: NEXUSpose absent from synchronized Blockbench test model.")
else:
    assert len(current_pose.get("animators", {})) > 0
    print("NEXUSpose found; runtime loader will sample its first authored keyframe.")

# Verify the source rig can map most authoring bone UUIDs into its skeleton.
test_pose = next(a for a in display["animations"] if a["name"]=="Wait_Pose")
source_pose = next(a for a in canonical["animations"] if a["name"]=="Wait_Pose")
assert len(set(test_pose["animators"]) & set(source_pose["animators"])) >= 20

# Preserve user-requested background, menu, spin and original gameplay assets.
assert 'focus_panel.add_theme_stylebox_override("panel", _menu_body_style())' in s
assert "func _rotate_customization_preview(delta_x: float)" in s
assert "InputEventScreenDrag" in s
assert "CUSTOMIZE_PREVIEW_ROTATION_SAMPLES" in s
assert "back_panel.position = Vector2(view.x - margin - 62.0, view.y - margin - 62.0)" in s
assert "CAMERA_TRANSITION_SECONDS: float = 0.18" in s
assert s.count("SeraRig.new()") == 1
assert ".reparent(" not in s
clips = {a["name"] for a in display["animations"]}
assert {"Bash","Guard_REACTION"}.issubset(clips)

print("v130 enlargement, optional named pose loader, and existing navigation: PASS")
print("Static checks only; rendered preview size and animation pose remain unverified.")
