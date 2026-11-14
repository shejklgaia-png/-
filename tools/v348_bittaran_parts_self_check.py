#!/usr/bin/env python3
"""v348 Bittaran-only real-lock / independent mesh hits / leg skid contract."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
read = lambda p: (root / p).read_text(encoding="utf-8")
parts = read("scripts/bittaran_parts.gd")
battle = read("scripts/bittaran_battle.gd")
ik = read("scripts/bittaran_foot_ik.gd")
for name in ("FrontLowerLeg_L", "FrontLowerLeg_R",
             "RearLowerLeg_L", "RearLowerLeg_R"):
    assert name in parts
assert 'extends "res://scripts/target_parts.gd"' in parts
assert 'func get_body_hit_aabb() -> AABB:' in parts
assert 'func get_part_aabb(id: String) -> AABB:' in parts
assert 'func get_part_aim_world(id: String) -> Vector3:' in parts
assert 'func sync_bittaran_parts() -> void:' in parts
assert 'fx_meshes[""] = _material_records(bone_nodes[""], false)' in parts
assert 'fx_meshes["head"] = _material_records(bone_nodes["head"], true)' in parts
assert 'fx_meshes[id] = _material_records(root_leg, true)' in parts
assert 'target_parts = BittaranParts.new()' in battle
assert 'target_parts.call("sync_bittaran_parts")' in battle
assert 'func _apply_target_part_damage(' in battle
assert 'bittaran_foot_ik.call("start_leg_break_slide", hit_id, head_world.y,' in battle
assert 'func start_leg_break_slide(id: String, head_world_y: float,' in ik
assert 'const LEG_BREAK_REACTION_SECONDS: float = 2.5' in ik
assert 'const ALL_LEGS_BREAK_REACTION_SECONDS: float = 6.0' in ik
assert 'const LEG_BREAK_SLIDE_METERS: float = 1.05' in ik
assert 'const HEAD_MELEE_REACH_WORLD_Y: float = 1.35' in ik
assert 'break_elapsed = -1.0' in ik
print("PASS v348 six moving locks, isolated hit FX and grounded skid/crouch recovery")
