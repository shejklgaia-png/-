#!/usr/bin/env python3
"""SERA v317 Stage12: keep reverse/left nozzle priorities and actor/screen axes."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
nozzle = (ROOT / "scripts/sera_nozzle_steering.gd").read_text(encoding="utf-8")

assert 'const NOZZLE_STEERING = preload("res://scripts/sera_nozzle_steering.gd")' in main
assert "extends RefCounted" in nozzle
for name in ("backstroke_weight", "leftward_weight", "left_sector_direction"):
    assert f"static func {name}(" in nozzle, name
    assert f"NOZZLE_STEERING.{name}(" in main, name
for forbidden in ("get_tree(", "get_node(", "get_viewport(", "rig.call(", "touch_ui",
                  "part_stats", "enemy_shooter", "static var ", "FileAccess",
                  "Dictionary.new(", "Array.new(", "_screen_drag_to_ground("):
    assert forbidden not in nozzle, forbidden

physics = main.split("func _physics_process(delta: float) -> void:", 1)[1].split(
    "func _process(delta: float) -> void:", 1)[0]
start = physics.index("var direction_of_exhaust: Vector3 = MOTION_DIRECTION.exhaust_direction(")
last = physics.index('rig.call("update_back_thruster_fx", exhaust_on,', start)
fx = physics[start:last]
for token in (
    "var intended_boost: Vector3 = Vector3.ZERO",
    "if boost_exhaust or boost_pose_exhaust:",
    "intended_boost = _screen_drag_to_ground(direction_input)",
    "var backstroke_weight: float = NOZZLE_STEERING.backstroke_weight(",
    "stepping_this_frame, step_linear_fallback, step_linear_offset,",
    "step_flick_this_frame, step_side_this_frame, STEP_BACK,",
    "somersault_this_frame, back_somersault_launched,",
    "boost_exhaust, boost_pose_exhaust, intended_boost,",
    "player.global_transform.basis.z, held_boost_backstroke_weight)",
    "var leftward_weight: float = NOZZLE_STEERING.leftward_weight(",
    "stepping_this_frame, step_flick_this_frame, step_side_this_frame,",
    "boost_exhaust or boost_pose_exhaust, direction_input)",
    "var screen_right: Vector3 = Vector3.ZERO",
    "if exhaust_on and leftward_weight > 0.0:",
    "screen_right = _screen_drag_to_ground(Vector2.RIGHT).normalized()",
    "var left_sector_world: Vector3 = NOZZLE_STEERING.left_sector_direction(",
    "exhaust_on, leftward_weight, screen_right, backstroke_weight)",
    "if boost_pose_exhaust:",
    "held_boost_exhaust_direction = direction_of_exhaust.normalized()",
    "held_boost_backstroke_weight = backstroke_weight",
    "held_boost_left_sector_world = left_sector_world",
    "backstroke_weight = held_boost_backstroke_weight",
    "left_sector_world = held_boost_left_sector_world",
    "elif not boost_exhaust:",
    "held_boost_exhaust_direction = Vector3.ZERO",
    "held_boost_backstroke_weight = 0.0",
    "held_boost_left_sector_world = Vector3.ZERO",
):
    assert token in fx, token
ordered = [
    "MOTION_DIRECTION.exhaust_direction(",
    "var backstroke_weight: float = NOZZLE_STEERING.backstroke_weight(",
    "var leftward_weight: float = NOZZLE_STEERING.leftward_weight(",
    "if exhaust_on and leftward_weight > 0.0:",
    "NOZZLE_STEERING.left_sector_direction(",
    "if boost_pose_exhaust:",
    "held_boost_exhaust_direction = direction_of_exhaust.normalized()",
    "elif not boost_exhaust:",
]
assert [fx.index(x) for x in ordered] == sorted(fx.index(x) for x in ordered)
assert 'direction_of_exhaust.normalized(), delta, backstroke_weight,' in main
assert 'left_sector_world, acceleration_burst, normal_attack_exhaust)' in main
# The actual physical nozzle clamps in the FX layer, not in policy.
physical = (ROOT / "scripts/back_thruster_fx.gd").read_text(encoding="utf-8")
for name in ("YAW_LIMIT_RADIANS", "PITCH_UP_LIMIT_RADIANS", "PITCH_DOWN_LIMIT_RADIANS"):
    assert name in physical and name not in nozzle, name
for token in (
    "if stepping:",
    "step_linear_fallback and step_linear_offset.length_squared() > 0.000001",
    "step_linear_offset.x, 0.0, step_linear_offset.y).normalized()",
    "clampf(step_world_rear.dot(actor_rear), 0.0, 1.0)",
    "weight = clampf(step_flick.y, 0.0, 1.0)",
    "if step_side == step_back and step_flick.is_zero_approx():",
    "elif somersault and somersault_launched:",
    "elif boost_exhaust or boost_pose_exhaust:",
    "if intended_boost.length_squared() > 0.000001:",
    "weight = clampf(intended_boost.normalized().dot(actor_rear), 0.0, 1.0)",
    "weight = held_boost_weight",
    "weight = clampf(-step_flick.x, 0.0, 1.0)",
    "if step_side == -1 and step_flick.is_zero_approx():",
    "elif boost_or_pose and direction_input.length_squared() > 0.000001:",
    "weight = clampf(-direction_input.normalized().x, 0.0, 1.0)",
    "if not exhaust_on or left_weight <= 0.0:",
    "return Vector3.ZERO",
    "var left_sector_world: Vector3 = Vector3.DOWN.slerp(",
    "screen_right, left_weight * 0.50).normalized()",
    "left_sector_world = left_sector_world.slerp(",
    "Vector3.DOWN, backstroke).normalized()",
):
    assert token in nozzle, token
assert nozzle.index("screen_right, left_weight * 0.50).normalized()") < nozzle.index(
    "Vector3.DOWN, backstroke).normalized()")
print("SERA_NOZZLE_STEERING_STATIC_PASS")
