#!/usr/bin/env python3
"""SERA v317 lock extraction: public entry-points, dynamic receiver and constants."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
lock = (ROOT / "scripts/sera_lock_management.gd").read_text(encoding="utf-8")
assert 'const LOCK_MANAGEMENT = preload("res://scripts/sera_lock_management.gd")' in main
for name in ("select_auto_part", "manual_screen_neighbor",
             "target_facing_direction", "reticle_projection"):
    assert f"static func {name}(" in lock
    assert f"LOCK_MANAGEMENT.{name}(" in main
for token in (
    '"select_actor_parallel_lines_part", actor_origin, target_center',
    'var gap: float = (projected.x - reference_x) * float(direction)',
    'if gap > 3.0 and gap < forward_gap:',
    'view.global_position, boss_body',
    'return forward_id if not forward_id.is_empty() else wrapped_id',
    '"get_part_aim_world", part_id',
    'return Vector3(',
    'or view.is_position_behind(target_world):',
    'var edge_margin: float = 42.0',
    '"offscreen": is_offscreen',
):
    assert token in lock, token
for token in (
    "func _acquire_stable_camera_part(delta: float,",
    "func _switch_lock_screen_direction(direction: int) -> void:",
    "func _locked_target_facing_direction() -> Vector3:",
    "func _update_target_marker_projection() -> void:",
    "auto_lock_pending_elapsed = 0.0",
    "manual_part_lock_active = true",
    "or _combo_lock_retention_active()",
    "_update_target_marker_projection()",
):
    assert token in main, token
assert "get_tree()" not in lock and "user://" not in lock
assert "FileAccess" not in lock and "HTTPRequest" not in lock
print("SERA_LOCK_MODULE_STATIC_PASS")
