#!/usr/bin/env python3
"""NEXUS and intake FULL BODY must use the same real-mesh arm clearance solver."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
read = lambda p: (ROOT / p).read_text(encoding="utf-8")
nexus = read("scripts/command_nexus.gd")
preview = read("tools/equipment_intake/godot_preview.gd")
solver = read("scripts/sera_nexus_arm_clearance.gd")
stage = read("tools/equipment_intake/build_web_preview.py")
manifest = read("tools/sera_ci_manifest.txt")

assert 'const NexusArmClearance = preload("res://scripts/sera_nexus_arm_clearance.gd")' in nexus
assert 'const NexusArmClearance = preload("res://scripts/sera_nexus_arm_clearance.gd")' in preview
assert 'NexusArmClearance.new().fit(sera_display_rig, nexus_arm_rest_rotations)' in nexus
assert 'NexusArmClearance.new().fit(rig, rest)' in preview
for key in ("NEXUS_ARM_STEP_DEGREES: float = 1.5",
            "NEXUS_SHOULDER_STEP_DEGREES: float = 0.2",
            "NEXUS_SHOULDER_MAX_DEGREES: float = 3.2",
            "NEXUS_ARM_MAX_STEPS: int = 16",
            "NEXUS_ARM_CLEARANCE: float = 0.018"):
    assert key in solver, key
# Explicitly test the same dimensions, including 24-degree upper arm cap.
assert "const NEXUS_ARM_STEP_DEGREES: float = 1.5" in nexus
assert "const NEXUS_ARM_MAX_STEPS: int = 16" in nexus
assert "for side in [\"L\", \"R\"]:" in solver
assert "_nexus_mesh_bounds_in_rig(piece).grow(NEXUS_ARM_CLEARANCE)" in solver
assert '_nexus_boxes_overlap(arm_obb, leg_data["obb"])' in solver
assert "if original_contacts == 0:" in solver
assert "if contacts < best_contacts:" in solver
assert "if contacts == 0:" in solver
assert "if best_step == 0:" in solver
assert "func _restore_nexus_arm_pose()" in solver
assert "func _fit_nexus_arms_to_lower_body()" in solver
# BODY uses selected visible meshes after editing-slot scale; ICON bypasses fit.
body = preview[preview.index("func _apply_equipment()"):preview.index("func _apply_frame()")]
assert body.index("_apply_preview_standing_pose()") < body.index("_apply_edit_size()")
assert body.index("_apply_edit_size()") < body.index("_fit_full_body_clearance()")
assert body.index("_fit_full_body_clearance()") < body.index("_apply_frame()")
assert 'if view_mode != "body" or rig == null:' in preview
assert "if view_mode==\"icon\":" in preview
assert "func _fit_full_body_clearance()" in preview
assert 'gd tools/equipment_intake/preview_runtime_check.gd' in manifest
assert 'py tools/equipment_intake/arm_clearance_contract_self_check.py' in manifest
assert "PRELOAD_RE" in stage # Auto-stage the shared GDScript into Web WASM.
print("SERA_INTAKE_NEXUS_CLEARANCE_CONTRACT_OK")
