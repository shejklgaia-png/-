#!/usr/bin/env python3
"""v298 regression: BODY competes equally with intact limbs on finite camera line."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
project = (root/"project.godot").read_text(encoding="utf-8")
parts = (root/"scripts/target_parts.gd").read_text(encoding="utf-8")
main = (root/"scripts/main.gd").read_text(encoding="utf-8")
manifest = (root/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert re.search(r'config/name="SERA v298"',project)
assert (root/"README_v298_ja.md").is_file()

body=parts.split("func _camera_center_line_body_distance(",1)[1].split(
    "func camera_center_line_hits_part(",1)[0]
for token in (
    "get_parent() as MeshInstance3D",
    "core_mesh.mesh is BoxMesh",
    "core_mesh.visible",
    "(core_mesh.mesh as BoxMesh).size",
    "AABB(-core_size * 0.5, core_size).intersects_segment(",
    "core_mesh.to_local(camera_origin), core_mesh.to_local(body_center)",
    "if contact == null:",
    "core_mesh.to_global(contact)",
    "camera_origin.distance_squared_to(contact_world)",
):
    assert token in body,token
assert "return INF" in body
assert "get_part_aabb" not in body

hit=parts.split("func camera_center_line_hits_part(",1)[1].split(
    "func select_camera_center_line_part(",1)[0]
assert "if id.is_empty():" in hit
assert "_camera_center_line_body_distance(" in hit
assert "_camera_center_line_part_distance(" in hit

selection=parts.split("func select_camera_center_line_part(",1)[1].split(
    "# v293 legacy orbital selector",1)[0]
assert "var closest: float = _camera_center_line_body_distance(origin, body_center)" in selection
assert 'var selected: String = ""' in selection
assert "for id in PART_ORDER:" in selection
assert "_camera_center_line_part_distance(" in selection
assert "if distance < closest:" in selection
assert "return selected" in selection

auto=main.split("func _acquire_stable_camera_part(delta: float,",1)[1].split(
    "func _controller_start_area_contains(",1)[0]
assert "auto_lock_initialized" in auto
assert 'camera, center, locked_target_part_id' in auto
assert "not locked_target_part_id.is_empty()" not in auto
assert "not auto_lock_initialized or current_broken or not current_on_line" in auto
assert "auto_lock_pending_part != preferred" in auto
assert "auto_lock_pending_elapsed >= AUTO_LOCK_SWITCH_CONFIRM_SECONDS" in auto
assert "_combo_lock_retention_active()" in main

for entry in (
    "py tools/v298_core_equal_auto_lock_self_check.py",
    "gd tools/v298_core_equal_auto_lock_runtime_check.gd",
):
    assert entry in manifest,entry
print("V298_CORE_EQUAL_AUTO_LOCK_STATIC_PASS")
