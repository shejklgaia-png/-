#!/usr/bin/env python3
"""SERA v296: real CAMERA->BODY-center mesh intersections gate AUTO part locks."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
parts = (root / "scripts/target_parts.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert int(re.search(r'config/name="SERA v(\d+)"', project).group(1)) >= 296
assert (root / "README_v296_ja.md").is_file()
selector = parts.split("func _camera_center_line_part_distance(", 1)[1].split(
    "# v293 legacy orbital selector", 1)[0]
for token in (
    "not is_targetable(id)",
    "pivot.get_children()",
    "child is MeshInstance3D",
    "not mesh_node.visible",
    "mesh_node.mesh is BoxMesh",
    "mesh_node.to_local(camera_origin)",
    "mesh_node.to_local(body_center)",
    "intersects_segment(",
    "if contact == null:",
    "mesh_node.to_global(contact)",
    "camera_origin.distance_squared_to(contact_world)",
    "return closest",
    "func actor_center_line_hits_part(",
    "func select_actor_center_line_part(",
    "if distance < closest:",
    "return selected",
):
    assert token in selector, token
assert "get_part_aabb" not in selector
assert "select_camera_orbit_part" not in selector
assert "unproject_position" not in selector

auto = main.split("func _acquire_stable_camera_part(delta: float,", 1)[1].split(
    "func _controller_start_area_contains(", 1)[0]
for token in (
    "target.global_position",
    "sera_origin: Vector3 = player.global_position",
    '"select_actor_parallel_lines_part", sera_origin, center',
    "locked_target_part_id = preferred",
    "auto_lock_initialized = true",
    'auto_lock_pending_part = ""',
    "auto_lock_pending_elapsed = 0.0",
):
    assert token in auto, token
assert "select_camera_orbit_part" not in auto
assert '"actor_parallel_lines_hits_part",' not in auto

physics = main.split("func _physics_process(delta: float) -> void:", 1)[1].split(
    "func _process(delta: float) -> void:", 1)[0]
assert "var combo_held: bool = _combo_lock_retention_active()" in physics
assert "if not combo_held:" in physics
assert "_acquire_stable_camera_part(delta, locked_part_broken)" in physics
assert "if locked_part_broken:" in physics
assert "auto_lock_pending_part = \"\"" in physics
assert 'player.look_at(player.global_position + aim, Vector3.UP)' in physics

manual = main.split("func _switch_lock_screen_direction(direction: int)", 1)[1].split(
    "func _update_target_marker_projection(", 1)[0]
assert 'get_visible_part_ids' in manual
assert "manual_part_lock_active = true" in manual
assert "_combo_lock_retention_active()" in manual

for entry in (
    "py tools/v296_camera_center_mesh_lock_self_check.py",
    "gd tools/v296_camera_center_mesh_lock_runtime_check.gd",
):
    assert entry in manifest, entry
print("V296_CAMERA_CENTER_MESH_LOCK_STATIC_PASS")
