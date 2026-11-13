#!/usr/bin/env python3
"""Stage11: local RUN heading and rear-thruster direction extraction."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
direction = (ROOT / "scripts/sera_motion_direction.gd").read_text(encoding="utf-8")
assert 'const MOTION_DIRECTION = preload("res://scripts/sera_motion_direction.gd")' in main
assert "extends RefCounted" in direction
assert "static func local_run_direction(" in direction
assert "static func exhaust_direction(" in direction
for forbidden in ("get_tree(", "get_node(", "get_viewport(", "rig.call(", "part_stats",
                  "enemy_shooter", "touch_ui", "static var ", "FileAccess",
                  "get_ticks_msec()", "Dictionary.new(", "Array.new("):
    assert forbidden not in direction, forbidden
local = main.split("elif combat_state == CombatState.IDLE and not stepping_this_frame:", 1)[1].split(
    "        if running:", 1)[0]
for phrase in (
    "var world_move: Vector3 = _screen_drag_to_ground(direction_input) if running else Vector3.ZERO",
    "var target_forward: Vector3 = _locked_target_facing_direction()",
    "var local_run_direction: Vector2 = MOTION_DIRECTION.local_run_direction(",
    "world_move, target_forward, -player.global_transform.basis.z)",
    "var show_boost_pose: bool = (",
    "var show_moving_pose: bool = running or (",
    'rig.call("set_moving", show_moving_pose, show_boost_pose,',
    "local_run_direction, movement_boost_active)",
):
    assert phrase in local, phrase
assert local.index("var world_move:") < local.index("var target_forward:") < local.index(
    "MOTION_DIRECTION.local_run_direction(") < local.index('rig.call("set_moving"')
for phrase in (
    "if facing.length_squared() < 0.000001:",
    "facing = default_forward",
    "facing = facing.normalized()",
    "world_move.dot(facing.cross(Vector3.UP))",
    "world_move.dot(facing)",
):
    assert phrase in direction, phrase

physics = main.split("func _physics_process(delta: float) -> void:", 1)[1].split(
    "func _process(delta: float) -> void:", 1)[0]
start = physics.index("var boost_exhaust: bool = movement_boost_active and running")
fx = physics[start:physics.index('rig.call("update_back_thruster_fx"', start)]
for phrase in (
    "var boost_pose_exhaust: bool = (",
    "var tracking_exhaust: bool = (",
    "var normal_attack_exhaust: bool = normal_melee_exhaust or normal_kick_exhaust",
    "var exhaust_on: bool = PHYSICS_FRAME.exhaust_allowed(",
    "var acceleration_burst: bool = PHYSICS_FRAME.acceleration_burst(",
    "var requested_boost: Vector3 = Vector3.ZERO",
    "if boost_pose_exhaust and running:",
    "requested_boost = _screen_drag_to_ground(direction_input)",
    "var direction_of_exhaust: Vector3 = MOTION_DIRECTION.exhaust_direction(",
    "blur_velocity, boost_pose_exhaust, running, requested_boost,",
    "held_boost_exhaust_direction, somersault_this_frame,",
    "back_somersault_launched, back_somersault_direction,",
    "normal_attack_exhaust, tracking_exhaust, stepping_this_frame,",
    "player.global_transform.basis.z)",
    "var backstroke_weight: float = 0.0",
    "var leftward_weight: float = 0.0",
    "var left_sector_world: Vector3 = Vector3.ZERO",
    "held_boost_exhaust_direction = direction_of_exhaust.normalized()",
    "direction_of_exhaust.normalized(), delta, backstroke_weight,",
    "left_sector_world, acceleration_burst, normal_attack_exhaust)",
):
    assert phrase in physics or phrase in fx, phrase
assert fx.index("var exhaust_on:") < fx.index("var requested_boost:") < fx.index(
    "MOTION_DIRECTION.exhaust_direction(") < fx.index("var backstroke_weight:")
assert fx.index("var backstroke_weight:") < fx.index("var leftward_weight:") < fx.index(
    "var left_sector_world:")
for phrase in (
    "var direction_of_exhaust: Vector3 = -blur_velocity",
    "direction_of_exhaust.y = 0.0",
    "if boost_pose_exhaust and running:",
    "if requested_boost.length_squared() > 0.000001:",
    "direction_of_exhaust = -requested_boost.normalized()",
    "elif boost_pose_exhaust and held_boost_direction.length_squared() > 0.000001:",
    "direction_of_exhaust = held_boost_direction",
    "if somersault_this_frame and somersault_launched:",
    "direction_of_exhaust = -somersault_direction",
    "if normal_attack_exhaust and not tracking_exhaust",
    "and not (somersault_this_frame and somersault_launched)",
    "and not stepping_this_frame:",
    "direction_of_exhaust = actor_rear",
    "if direction_of_exhaust.length_squared() < 0.0004:",
):
    assert phrase in direction, phrase
print("SERA_MOTION_DIRECTION_STATIC_PASS")
