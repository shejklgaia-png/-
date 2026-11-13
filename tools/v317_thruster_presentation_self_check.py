#!/usr/bin/env python3
"""SERA v317 Stage13: FX cache ownership, neutral/reversal and dispatch ordering."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
module = (ROOT / "scripts/sera_thruster_presentation.gd").read_text(encoding="utf-8")
assert 'const THRUSTER_PRESENTATION = preload("res://scripts/sera_thruster_presentation.gd")' in main
assert "var thruster_presentation = THRUSTER_PRESENTATION.new()" in main
assert "extends RefCounted" in module
assert "func update(rig: Node, exhaust_on: bool, direction_of_exhaust: Vector3," in module
for field in ("held_boost_exhaust_direction", "held_boost_backstroke_weight",
              "held_boost_left_sector_world"):
    assert f"var {field}:" in module, field
    assert f"var {field}:" not in main, field
    assert f"thruster_presentation.{field}" in main, field
for forbidden in ("get_tree(", "get_node(", "get_viewport(", "touch_ui", "part_stats",
                  "static var ", "FileAccess", "Array.new(", "Dictionary.new(",
                  "_screen_drag_to_ground(", "rig.new(", "add_child("):
    assert forbidden not in module, forbidden

physics = main.split("func _physics_process(delta: float) -> void:", 1)[1].split(
    "func _process(delta: float) -> void:", 1)[0]
fx = physics.split("var direction_of_exhaust: Vector3 = MOTION_DIRECTION.exhaust_direction(", 1)[1].split(
    "_update_melee_lock_marker()", 1)[0]
required = (
    "blur_velocity, boost_pose_exhaust, running, requested_boost,",
    "thruster_presentation.held_boost_exhaust_direction, somersault_this_frame,",
    "var backstroke_weight: float = NOZZLE_STEERING.backstroke_weight(",
    "player.global_transform.basis.z, thruster_presentation.held_boost_backstroke_weight)",
    "var leftward_weight: float = NOZZLE_STEERING.leftward_weight(",
    "var left_sector_world: Vector3 = NOZZLE_STEERING.left_sector_direction(",
    "thruster_presentation.update(rig, exhaust_on,",
    "direction_of_exhaust, delta, backstroke_weight, left_sector_world,",
    "acceleration_burst, normal_attack_exhaust,",
    "boost_pose_exhaust, running, boost_exhaust)",
)
for token in required:
    assert token in fx, token
ordered = (
    "NOZZLE_STEERING.backstroke_weight(",
    "NOZZLE_STEERING.leftward_weight(",
    "NOZZLE_STEERING.left_sector_direction(",
    "thruster_presentation.update(rig, exhaust_on,",
)
assert [fx.index(s) for s in ordered] == sorted(fx.index(s) for s in ordered)
assert 'rig.call("update_back_thruster_fx"' not in main
for token in (
    "if boost_pose_exhaust:",
    "if running:",
    "held_boost_exhaust_direction = direction_of_exhaust.normalized()",
    "held_boost_backstroke_weight = backstroke_weight",
    "held_boost_left_sector_world = left_sector_world",
    "elif held_boost_exhaust_direction.length_squared() > 0.000001:",
    "backstroke_weight = held_boost_backstroke_weight",
    "left_sector_world = held_boost_left_sector_world",
    "elif not boost_exhaust:",
    "held_boost_exhaust_direction = Vector3.ZERO",
    "held_boost_backstroke_weight = 0.0",
    "held_boost_left_sector_world = Vector3.ZERO",
    'rig.call("update_back_thruster_fx", exhaust_on,',
    "direction_of_exhaust.normalized(), delta, backstroke_weight,",
    "left_sector_world, acceleration_burst, normal_attack_exhaust)",
):
    assert token in module, token
order = (
    "if boost_pose_exhaust:",
    "if running:",
    "held_boost_exhaust_direction = direction_of_exhaust.normalized()",
    "elif held_boost_exhaust_direction.length_squared() > 0.000001:",
    "backstroke_weight = held_boost_backstroke_weight",
    "left_sector_world = held_boost_left_sector_world",
    "elif not boost_exhaust:",
    "held_boost_exhaust_direction = Vector3.ZERO",
    'rig.call("update_back_thruster_fx", exhaust_on,',
)
assert [module.index(s) for s in order] == sorted(module.index(s) for s in order)
# No hidden scene effects have moved from main: all rendering and authored
# nozzle angle limits remain with the rig/equipment/FX scripts.
rig = (ROOT / "scripts/sera_rig.gd").read_text(encoding="utf-8")
equip = (ROOT / "scripts/sera_equipment.gd").read_text(encoding="utf-8")
physical = (ROOT / "scripts/back_thruster_fx.gd").read_text(encoding="utf-8")
assert 'equipment_handler.call("update_back_thruster_fx",' in rig
assert 'active, exhaust_world, delta, backstroke_weight,' in rig
assert 'exhaust_world, delta, backstroke_weight, left_sector_world,' in equip
for token in ("YAW_LIMIT_RADIANS", "PITCH_UP_LIMIT_RADIANS", "PITCH_DOWN_LIMIT_RADIANS"):
    assert token in physical and token not in module
print("SERA_THRUSTER_PRESENTATION_STATIC_PASS")
