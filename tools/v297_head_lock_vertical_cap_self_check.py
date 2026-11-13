#!/usr/bin/env python3
"""v297: head-only 1m upward AUTO-lock cap without touching combat geometry."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
parts = (root / "scripts/target_parts.gd").read_text(encoding="utf-8")
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert int(re.search(r'config/name="SERA v(\d+)"', project).group(1)) >= 297
assert (root / "README_v297_ja.md").is_file()
assert "const HEAD_LOCK_UPWARD_EXTENSION_METERS: float = 1.0" in parts
selector = parts.split("func _camera_center_line_part_distance(",1)[1].split(
    "func camera_center_line_hits_part(",1)[0]
assert "if id == \"head\":" in selector
head = selector.split('if id == "head":',1)[1]
for token in (
    'var head_size: Vector3 = parts[id]["size"]',
    'Vector3(-head_size.x * 0.5, -head_size.y * 0.5,',
    'Vector3(head_size.x, head_size.y + HEAD_LOCK_UPWARD_EXTENSION_METERS,',
    'overhead.intersects_segment(',
    'pivot.to_local(camera_origin), pivot.to_local(body_center)',
    'if overhead_contact != null:',
    'pivot.to_global(overhead_contact)',
    'camera_origin.distance_squared_to(overhead_world)',
):
    assert token in head, token
assert selector.index('for child in pivot.get_children():') < selector.index('if id == "head":')
assert "get_part_aabb" not in selector
assert "get_part_aim_world" not in selector
assert "sera_origin: Vector3 = player.global_position" in main
assert "select_camera_orbit_part" not in selector
assert "HEAD_LOCK_UPWARD_EXTENSION_METERS" not in main
assert 'func get_part_aabb(id: String) -> AABB:' in parts
assert "func install_movement_colliders(" in parts
assert 'func get_part_aim_world(id: String) -> Vector3:' in parts
auto = main.split("func _acquire_stable_camera_part(delta: float,",1)[1].split(
    "func _controller_start_area_contains(",1)[0]
assert '"select_actor_parallel_lines_part", sera_origin, center' in auto
assert '"actor_parallel_lines_hits_part",' in auto
physics = main.split("func _physics_process(delta: float) -> void:",1)[1].split(
    "func _process(delta: float) -> void:",1)[0]
assert "var combo_held: bool = _combo_lock_retention_active()" in physics
assert "if not combo_held:" in physics
assert "_acquire_stable_camera_part(delta, locked_part_broken)" in physics
for entry in (
    "py tools/v297_head_lock_vertical_cap_self_check.py",
    "gd tools/v297_head_lock_vertical_cap_runtime_check.gd",
):
    assert entry in manifest, entry
print("V297_HEAD_LOCK_VERTICAL_CAP_STATIC_PASS")
