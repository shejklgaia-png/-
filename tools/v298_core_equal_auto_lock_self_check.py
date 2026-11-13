#!/usr/bin/env python3
"""v298 regression: BODY competes equally with intact limbs on finite camera line."""
from pathlib import Path

# v317: AUTO state remains in main; paired-ray selection moved to a pure module.
from pathlib import Path as _LockPath
LOCK_MODULE = (_LockPath(__file__).resolve().parents[1] / "scripts/sera_lock_management.gd").read_text(encoding="utf-8")
import re

root = Path(__file__).resolve().parents[1]
project = (root/"project.godot").read_text(encoding="utf-8")
parts = (root/"scripts/target_parts.gd").read_text(encoding="utf-8")
main = (root/"scripts/main.gd").read_text(encoding="utf-8")
manifest = (root/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert int(re.search(r'config/name="SERA v(\d+)"',project).group(1)) >= 298
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

hit=parts.split("func actor_center_line_hits_part(",1)[1].split(
    "func select_actor_center_line_part(",1)[0]
assert "if id.is_empty():" in hit
assert "_camera_center_line_body_distance(" in hit
assert "_camera_center_line_part_distance(" in hit

selection=parts.split("func select_actor_center_line_part(",1)[1].split(
    "# Read-only legacy camera-origin APIs",1)[0]
assert "var closest: float = _camera_center_line_body_distance(actor_origin, body_center)" in selection
assert 'var selected: String = ""' in selection
assert "for id in PART_ORDER:" in selection
assert "_camera_center_line_part_distance(" in selection
assert "if distance < closest:" in selection
assert "return selected" in selection

auto=main.split("func _acquire_stable_camera_part(delta: float,",1)[1].split(
    "# v305: yaw SERA toward the actual current LOCK target.",1)[0]
assert "auto_lock_initialized" in auto
assert 'LOCK_MANAGEMENT.select_auto_part(' in auto
assert "target_parts, player.global_position, target.global_position" in auto
assert "not locked_target_part_id.is_empty()" not in auto
assert "locked_target_part_id = LOCK_MANAGEMENT.select_auto_part(" in auto
assert "auto_lock_pending_part != preferred" not in auto
assert "AUTO_LOCK_SWITCH_CONFIRM_SECONDS" not in auto
assert "_combo_lock_retention_active()" in main

for entry in (
    "py tools/v298_core_equal_auto_lock_self_check.py",
    "gd tools/v298_core_equal_auto_lock_runtime_check.gd",
):
    assert entry in manifest,entry
print("V298_CORE_EQUAL_AUTO_LOCK_STATIC_PASS")

# The authoritative selection API is still the same actor-origin dual-line method.
assert '"select_actor_parallel_lines_part", actor_origin, target_center' in LOCK_MODULE
