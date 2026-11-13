#!/usr/bin/env python3
"""v301 SERA->BODY AUTO lock; camera projection remains MANUAL/HUD only."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
target = (root/"scripts/target_parts.gd").read_text(encoding="utf-8")
main = (root/"scripts/main.gd").read_text(encoding="utf-8")
project = (root/"project.godot").read_text(encoding="utf-8")
manifest = (root/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert re.search(r'config/name="SERA v301"',project)
assert (root/"README_v301_ja.md").is_file()

auto = main.split("func _acquire_stable_camera_part(delta: float,",1)[1].split(
    "func _controller_start_area_contains(",1)[0]
assert "sera_origin: Vector3 = player.global_position" in auto
assert '"select_actor_center_line_part", sera_origin, center' in auto
assert '"actor_center_line_hits_part",' in auto
assert 'sera_origin, center, locked_target_part_id' in auto
assert "camera.global_position" not in auto
assert '"select_camera_center_line_part"' not in auto
assert "if target_parts == null or player == null or target == null:" in auto
assert "target.global_position" in auto
assert "not auto_lock_initialized or current_broken or not current_on_line" in auto
assert "auto_lock_pending_elapsed >= AUTO_LOCK_SWITCH_CONFIRM_SECONDS" in auto
assert "_combo_lock_retention_active()" in main
assert "_acquire_stable_camera_part(delta, locked_part_broken)" in main

hits=target.split("func actor_center_line_hits_part(",1)[1].split(
    "# Read-only legacy camera-origin APIs",1)[0]
for token in (
    'actor_origin: Vector3,',
    'if id.is_empty():',
    '_camera_center_line_body_distance(actor_origin, body_center)',
    '_camera_center_line_part_distance(actor_origin, body_center, id)',
    'var closest: float = _camera_center_line_body_distance(actor_origin, body_center)',
    'for id in PART_ORDER:',
    'if distance < closest:',
    'return selected',
):
    assert token in hits,token
assert "Camera3D" not in hits
assert "get_part_aabb" not in hits
assert "unproject_position" not in hits
assert "is_targetable" in target.split("func _camera_center_line_part_distance(",1)[1].split(
    "func _camera_center_line_body_distance(",1)[0]
assert 'if id == "head":' in target
assert "HEAD_LOCK_UPWARD_EXTENSION_METERS" in target
assert "HEAD_LOCK_FORWARD_EXTENSION_METERS" in target

# Manual arrow buttons continue to use projected camera screen X and wrap.
manual = main.split("func _switch_lock_screen_direction(direction: int) -> void:",1)[1].split(
    "func _update_target_marker_projection()",1)[0]
assert "camera.unproject_position(aim)" in manual
assert 'forward_id if not forward_id.is_empty() else wrapped_id' in manual
marker = main.split("func _update_target_marker_projection() -> void:",1)[1].split(
    "func _",1)[0]
assert "camera.unproject_position(center_world)" in marker
for path in (
    "py tools/v301_sera_target_center_lock_self_check.py",
    "gd tools/v301_sera_target_center_lock_runtime_check.gd"
):
    assert path in manifest,path
print("V301_SERA_TARGET_LOCK_STATIC_PASS")
