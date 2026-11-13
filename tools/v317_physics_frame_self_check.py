#!/usr/bin/env python3
"""Stage10: physics-frame math isolation, real state ownership and gate ordering."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
rules = (ROOT / "scripts/sera_physics_frame_rules.gd").read_text(encoding="utf-8")
assert 'const PHYSICS_FRAME = preload("res://scripts/sera_physics_frame_rules.gd")' in main
assert "extends RefCounted" in rules
for name in ("next_boost_pose_grace", "flight_owns_displacement",
             "displacement_velocity", "exhaust_allowed", "acceleration_burst"):
    assert f"static func {name}(" in rules, name
    assert f"PHYSICS_FRAME.{name}(" in main, name
for forbidden in ("get_tree(", "get_node(", "get_viewport(", "touch_ui",
                  "part_stats", "rig.call(", "Label.new(", "static var ",
                  "FileAccess", "set_physics_process(", "Array.new("):
    assert forbidden not in rules, forbidden
assert "return maxf(0.0, remaining - delta)" in rules
assert "if boost_active:" in rules and "return grace_seconds" in rules
assert "or back_somersault_active or not combat_idle:" in rules
assert "or somersault_this_frame or back_somersault_active or landing_active)" in rules
assert "if delta > 0.000001:" in rules
assert "return (current_position - previous_position) / delta" in rules
assert "return Vector3.ZERO" in rules
for token in (
    "not damage_active and not jumping and not landing",
    "and not guarding and not energy_exhausted",
    "boost_exhaust or boost_pose_exhaust or stepping",
    "or tracking_exhaust or attack_exhaust",
    "stepping and not previous_step",
    "or new_somersault_burst",
    "tracking_state >= 0",
    "tracking_state != previous_tracking_state",
):
    assert token in rules, token

def section(start: str, stop: str) -> str:
    assert main.count(start) == 1, start
    return main.split(start, 1)[1].split(stop, 1)[0]

wrapper = section("func _tick_boost_pose_grace(delta: float) -> void:",
                  "func _physics_process(delta: float) -> void:")
for token in (
    "boost_pose_grace_remaining = PHYSICS_FRAME.next_boost_pose_grace(",
    "boost_pose_grace_remaining, delta, BOOST_POSE_GRACE_SECONDS,",
    "gesture_active, guard_active, damage_reaction_active,",
    "jump_active, landing_active, step_active, back_somersault_active,",
    "combat_state == CombatState.IDLE, movement_boost_active",
):
    assert token in wrapper, token
physics = section("func _physics_process(delta: float) -> void:",
                  "func _process(delta: float) -> void:")
ordered = [
    "_tick_training_ko(delta)",
    "_tick_combo_window_timers(delta)",
    "    var was_energy_exhausted: bool = energy_exhausted",
    "_tick_target_recovery_timers(delta)",
    "_update_boost_speed(delta)",
    "_tick_boost_pose_grace(delta)",
    "_update_enemy_fire_eligibility()",
    "var running: bool = direction_input.length() > 0.001",
    "_advance_side_step(delta)",
    "    if damage_reaction_active:\n        # Freeze player input while physical knockback",
    "elif PHYSICS_FRAME.flight_owns_displacement(",
    "elif combat_state == CombatState.IDLE and not stepping_this_frame:",
    "blur_velocity = PHYSICS_FRAME.displacement_velocity(",
    "blur_last_player_position = player.global_position",
    "_acquire_stable_camera_part(delta, locked_part_broken)",
    "rig.call(\"update_omni_step_direction\"",
    "var boost_exhaust: bool = movement_boost_active and running",
    "var normal_melee_exhaust: bool = (",
    "var exhaust_on: bool = PHYSICS_FRAME.exhaust_allowed(",
    "var acceleration_burst: bool = PHYSICS_FRAME.acceleration_burst(",
    "thruster_accel_previous_step = stepping_this_frame",
    "thruster_presentation.update(rig, exhaust_on,",
]
indices = [physics.index(x) for x in ordered]
assert indices == sorted(indices), list(zip(ordered, indices))
presentation = (ROOT / "scripts/sera_thruster_presentation.gd").read_text(encoding="utf-8")
assert 'rig.call("update_back_thruster_fx", exhaust_on,' in presentation
assert "left_sector_world, acceleration_burst, normal_attack_exhaust)" in presentation
normal_resource = physics.index("    var was_energy_exhausted: bool = energy_exhausted")
assert normal_resource < physics.index("    _tick_resources(delta)", normal_resource) < physics.index(
    "    _tick_target_recovery_timers(delta)")
assert "player.move_and_slide()" in physics.split(
    "elif PHYSICS_FRAME.flight_owns_displacement(", 1)[1]
for token in (
    "jumping_this_frame, landing_this_frame, somersault_this_frame,",
    "back_somersault_active, landing_active):",
    "player.global_position, blur_last_player_position, delta)",
    "damage_reaction_active, jump_active, landing_active, guard_active,",
    "energy_exhausted, boost_exhaust, boost_pose_exhaust,",
    "stepping_this_frame, tracking_exhaust, normal_attack_exhaust)",
    "exhaust_on, stepping_this_frame, thruster_accel_previous_step,",
    "new_somersault_burst, tracking_accel_state,",
    "thruster_accel_previous_tracking_state)",
    "left_sector_world, acceleration_burst, normal_attack_exhaust)",
):
    assert token in physics, token
# Melee jets still persist through windup and post-hit follow-through.
normal = physics.split("var normal_melee_exhaust: bool = (", 1)[1].split(
    "var normal_kick_exhaust:", 1)[0]
for name in ("MELEE_APPROACH", "DASH", "STRIKE_TRACK", "STRIKE",
             "BASH_TRACK", "BASH", "BACK_KICK_TRACK"):
    assert f"combat_state == CombatState.{name}" in normal, name
assert "blur_velocity" not in normal and "strike_did_hit" not in normal
print("SERA_PHYSICS_FRAME_STATIC_PASS")
