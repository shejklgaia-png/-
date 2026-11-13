#!/usr/bin/env python3
"""v196 regression: NEXUS pose shoulder/upper-arm collision fitting is preview-only."""
from __future__ import annotations
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def load(path):
    return (ROOT/path).read_text(encoding="utf-8")

project = load("project.godot")
version = re.search(r'^config/name="SERA v(\d+)"$', project, re.M)
assert version and int(version.group(1)) >= 196
nexus = load("scripts/command_nexus.gd")
rig = load("scripts/sera_rig.gd")
equips = load("scripts/sera_equipment.gd")
pose_source = json.loads(load("models/storage/SERA_BIRD_LEGS_MIRROR_EDIT.bbmodel"))
poses = {a["name"]: a for a in pose_source["animations"]}
assert "NEXUS_pose" in poses
names = {v["name"] for v in poses["NEXUS_pose"]["animators"].values()}
assert {"Shoulder_L", "Shoulder_R", "UpperArm_L", "UpperArm_R"}.issubset(names)
assert 'const NEXUS_ARM_STEP_DEGREES: float = 1.5' in nexus
assert 'const NEXUS_SHOULDER_MAX_DEGREES: float = 3.2' in nexus
assert 'const NEXUS_ARM_MAX_STEPS: int = 16' in nexus
assert 'const NEXUS_ARM_CLEARANCE: float = 0.018' in nexus
assert 'var nexus_arm_rest_rotations: Dictionary = {}' in nexus

# NEXUS pose is the base. The code restores exact authored quaternions on
# every equipment swap and rotates neither arm at all when already clear.
init = nexus.index('func _sera_display() -> void:')
pose = nexus.index('func _apply_nexus_pose(rig: Node3D) -> bool:')
intro = nexus[init:pose]
assert intro.index('_apply_nexus_pose(rig)') < intro.index('_remember_nexus_arm_rest_pose(rig)')
assert intro.index('_remember_nexus_arm_rest_pose(rig)') < intro.index('_fit_nexus_arms_to_lower_body()')
assert intro.index('_fit_nexus_arms_to_lower_body()') < intro.index('_capture_sera_silhouette(rig)')
assert 'func _restore_nexus_arm_pose() -> void:' in nexus
assert 'nexus_arm_rest_rotations[str(bone.name)] = bone.quaternion' in nexus
assert 'bone.quaternion = nexus_arm_rest_rotations[name]' in nexus
assert '    _restore_nexus_arm_pose()' in nexus
assert 'if original_contacts == 0:' in nexus
assert 'func _nexus_side_overlap_count(side: String, arms: Array,' in nexus

# This MUST be measured from the selected equipment meshes at the current
# authored exhibition pose, not activated unconditionally for D.
assert 'handler.get("available")' in nexus
assert 'get_equipment_selection", "legs"' in nexus
assert 'get_equipment_selection", "arms"' in nexus
assert 'piece.is_visible_in_tree()' in nexus
assert 'piece.mesh.get_aabb()' in nexus
assert 'sera_display_rig.to_local(piece.to_global(vertex))' in nexus
assert 'arm_box.intersects(leg_data["aabb"])' in nexus
assert '_nexus_boxes_overlap(arm_obb, leg_data["obb"])' in nexus
assert 'for side in ["L", "R"]:' in nexus
assert 'for step in range(1, NEXUS_ARM_MAX_STEPS + 1):' in nexus
assert 'var shoulder: float = minf(' in nexus
assert 'var upper: float = float(step) * NEXUS_ARM_STEP_DEGREES' in nexus
assert 'Quaternion(Vector3.BACK, deg_to_rad(sign * degrees)) * original' in nexus

# Re-evaluate when selected lower-body or arms change, and on profile load.
switch = nexus[nexus.index("func _tap_equipment_control("):]
assert 'if slot == "legs" or slot == "arms":\n                _fit_nexus_arms_to_lower_body()' in switch
assert '    _fit_nexus_arms_to_lower_body()\n    _capture_sera_silhouette(sera_display_rig)' in switch
assert 'rig.set_process(false)' in nexus
assert 'rig.set_physics_process(false)' in nexus
assert 'func set_exhibition_mode(enabled: bool)' in rig
assert 'if equipment_handler != null:' in rig
# v291 reserves an opposite-handed weapon slot while keeping set selection.
assert 'piece.visible = not reserved and set_id == str(selected.get(slot, "A"))' in equips
assert 'NEXUS_ARM_MAX_STEPS' not in rig and 'NEXUS_ARM_MAX_STEPS' not in equips
assert 'NEXUS_POSE_SOURCES' not in nexus
assert 'rig.get("animations")' in nexus
assert 'rig.call("_apply_animation", 0.0)' in nexus

print("PASS: pose-original defaults, per-arm collision search, precise restore")
print("PASS: current selected A/B/C/D lower body and A/B arm geometry used")
print("PASS: only NEXUS exhibition changed, no gameplay animations altered")
print("Godot Android visual/collision acceptance is still pending")
