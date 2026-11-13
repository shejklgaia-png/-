#!/usr/bin/env python3
"""v293 historical orbital selector contract; v296 AUTO now uses mesh segment."""
from pathlib import Path
import math, re
root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
parts = (root / "scripts/target_parts.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
assert (int(re.search(r'config/name="SERA v(\d+)"', project).group(1)) >= 293)
order = ["head", "", "leg_fl", "", "leg_rl", "", "leg_rr", "", "leg_fr", ""]
ring = parts.split("const CAMERA_ORBIT_RING = [",1)[1].split("]",1)[0]
actual = re.findall(r'"([^"]*)"', ring)
assert actual == order, actual
selector = parts.split("func select_camera_orbit_part(view_camera: Camera3D) -> String:",1)[1].split(
    "# v291: camera-forward locking.",1)[0]
for key in ("to_local(view_camera.global_position)",
            "atan2(-relative.x, relative.z)", "CAMERA_ORBIT_STEP_DEGREES",
            "posmod(", "roundi(", "is_targetable(part_id) else \"\""):
    assert key in selector, key
assert "unproject_position" not in selector
assert "intersects_segment" not in selector
def select(x,z,broken=frozenset()):
    degrees = math.degrees(math.atan2(-x,z)) % 360
    # Godot roundi() rounds positive half-steps away from zero; Python round() uses banker's rounding.
    slot = int(math.floor(degrees / 36 + 0.5)) % 10
    item = order[slot]
    return "" if item in broken else item
for i,expected in enumerate(order):
    angle = math.radians(i*36)
    assert select(-math.sin(angle),math.cos(angle)) == expected, (i,expected)
assert select(0,1) == "head"
# Check sector centers, not exact halfway boundaries where rounding ties
# legitimately belong to either neighboring segment.
assert select(-math.sin(math.radians(108)), math.cos(math.radians(108))) == ""
assert select(0,-1) == ""
assert select(-math.sin(math.radians(252)), math.cos(math.radians(252))) == ""
assert select(-math.sin(math.radians(72)),math.cos(math.radians(72)),{"leg_fl"}) == ""
assert "var auto_lock_initialized: bool = false" in main
auto = main.split("func _acquire_stable_camera_part(delta: float,",1)[1].split(
    "func _controller_start_area_contains(",1)[0]
for key in ("select_actor_parallel_lines_part", "not auto_lock_initialized or current_broken:",
            "auto_lock_initialized = true", "auto_lock_pending_part != preferred",
            "auto_lock_pending_elapsed >= AUTO_LOCK_SWITCH_CONFIRM_SECONDS"):
    assert key in auto, key
assert "actor_center_line_hits_part" in auto
assert "sera_origin: Vector3 = player.global_position" in auto
assert "preferred == locked_target_part_id and current_on_line" in auto
assert 'var label_name: String = "BODY"' in main
assert "var integrity: float = float(target_hp)" in main
assert "var maximum: float = float(TARGET_MAX_HP)" in main
# Legacy MANUAL arrow selection remains camera-X based and otherwise unmodified.
manual = main.split("func _switch_lock_screen_direction(direction: int) -> void:",1)[1].split(
    "func _update_target_marker_projection()",1)[0]
assert "camera.unproject_position(aim)" in manual
assert "forward_id if not forward_id.is_empty() else wrapped_id" in manual
print("V293_AUTO_ORBIT_CORE_LOCK_STATIC_PASS")
