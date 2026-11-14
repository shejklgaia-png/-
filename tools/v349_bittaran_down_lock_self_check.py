#!/usr/bin/env python3
"""Bittaran v349 down-only lock eligibility; general training target stays intact."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
def read(path): return (root/path).read_text(encoding="utf-8")
parts=read("scripts/bittaran_parts.gd")
battle=read("scripts/bittaran_battle.gd")
ik=read("scripts/bittaran_foot_ik.gd")
assert 'var down_lock_enabled: bool = false' in parts
assert 'const BODY_MANUAL_LOCK_ID: String = "body"' in parts
assert 'func can_lock_boss_part(id: String) -> bool:' in parts
assert 'func is_targetable(id: String) -> bool:' in parts
assert 'func get_visible_part_ids(origin: Vector3, core_box: AABB)' in parts
assert 'func select_actor_parallel_lines_part(origin: Vector3,' in parts
assert 'return _nearest_lockable_shin(origin, body_center)' in parts
assert 'func apply_part_hit(id: String, raw_attack: float, raw_break: float)' in parts
assert 'super.apply_part_hit(_normalize_boss_part(id)' in parts
assert 'func _update_bittaran_lock_permissions() -> void:' in battle
assert 'not bool(target_parts.call(' in battle
assert 'target_parts.call("set_down_lock_enabled", down)' in battle
assert 'break_reaction_active' in battle and 'break_reaction_active' in ik
assert 'target_parts.call("set_down_lock_enabled", true)' in battle
assert 'target_parts.call("sync_bittaran_parts")' in battle
# Never modify generic lock management or training target to implement boss-specific rules.
assert 'const BittaranParts = preload("res://scripts/bittaran_parts.gd")' in battle
print("PASS v349 standing shin-only locks / down-only HEAD and BODY")
