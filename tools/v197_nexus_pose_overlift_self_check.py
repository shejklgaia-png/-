#!/usr/bin/env python3
"""v197: verify conservative OBB collision and capped minimal NEXUS arm lift."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

nexus = read("scripts/command_nexus.gd")
project = read("project.godot")
assert re.search(r'^config/name="SERA v197"$', project, re.M)

# v196 allowed 90-degree additional arm lift, visibly excessive on Android.
# 16 x 1.5 degrees = 24 additional degrees for the arm, 3.2 shoulder.
assert "const NEXUS_ARM_STEP_DEGREES: float = 1.5" in nexus
assert "const NEXUS_ARM_MAX_STEPS: int = 16" in nexus
assert "const NEXUS_SHOULDER_STEP_DEGREES: float = 0.2" in nexus
assert "const NEXUS_SHOULDER_MAX_DEGREES: float = 3.2" in nexus
assert "const NEXUS_ARM_CLEARANCE: float = 0.018" in nexus
assert 1.5 * 16 == 24.0
assert 0.2 * 16 == 3.2

# OBB/OBB separating-axis check confirms collisions AFTER broadphase AABB.
start = nexus.index("func _nexus_boxes_overlap(")
end = nexus.index("func _nexus_side_overlap_count(", start)
sat = nexus[start:end]
assert 'var aa: Array = a["axes"]' in sat
assert 'var ba: Array = b["axes"]' in sat
assert 'for i in range(3):\n        for j in range(3):' in sat
assert 'cross_axis.normalized()' in sat
assert 'if absf(delta.dot(axis)) > radius_a + radius_b + NEXUS_ARM_CLEARANCE:' in sat
assert 'return false' in sat and 'return true' in sat

collision = nexus[end:nexus.index("func _fit_nexus_arms_to_lower_body()", end)]
assert 'if not arm_box.intersects(leg_data["aabb"]):' in collision
assert '_nexus_boxes_overlap(arm_obb, leg_data["obb"])' in collision
assert 'overlaps += 1' in collision
assert 'piece.is_visible_in_tree()' in collision

fitter = nexus[nexus.index("func _fit_nexus_arms_to_lower_body()"):nexus.index("func _apply_nexus_pose(", end)]
assert '    _restore_nexus_arm_pose()' in fitter
assert 'var original_contacts: int = _nexus_side_overlap_count(side, arms, leg_boxes)' in fitter
assert 'if original_contacts == 0:' in fitter
assert 'var best_contacts: int = original_contacts' in fitter
assert 'var best_step: int = 0' in fitter
assert 'for step in range(1, NEXUS_ARM_MAX_STEPS + 1):' in fitter
assert 'if contacts < best_contacts:' in fitter
assert 'if contacts == 0:' in fitter
assert 'break # Minimum fully clear angle.' in fitter
assert 'if best_step == 0:' in fitter
assert '_set_nexus_side_raise(side, 0.0, 0.0)' in fitter
assert 'float(best_step) * NEXUS_ARM_STEP_DEGREES' in fitter
assert 'if best_contacts > 0:' in fitter
assert 'for side in ["L", "R"]:' in fitter
assert 'if slot == "legs" or slot == "arms":' in nexus
assert 'func _restore_nexus_arm_pose()' in nexus

print("PASS v197: capped 24-degree arm, 3.2-degree shoulder lift")
print("PASS v197: oriented-box narrowphase after broadphase, independent sides")
print("PASS v197: authored pose when clear and best-improvement fallback")
print("Android visual and pose collision remain device checks")
