#!/usr/bin/env python3
"""v317 Stage9: enemy gating, combo-safe respawn and shared reset contracts."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
life = (ROOT / "scripts/sera_target_lifecycle.gd").read_text(encoding="utf-8")
assert 'const TARGET_LIFECYCLE = preload("res://scripts/sera_target_lifecycle.gd")' in main
assert "extends RefCounted" in life
for sig in ("static func movement_frozen(", "static func fire_allowed(",
            "static func respawn_action("):
    assert sig in life, sig
for forbidden in ("get_tree(", "get_node(", "get_viewport(", "part_stats",
                  "target_parts", "enemy_shooter", "static var ", ".call("):
    assert forbidden not in life, forbidden
for source_token in (
    "not movement_enabled or warning_active or boss_hp <= 0",
    "stagger_remaining > 0.0 or part_break_remaining > 0.0",
    "down_remaining > 0.0 or training_ko_remaining > 0.0",
    "boss_hp > 0 and player_hp > 0.0",
    "stagger_remaining <= 0.0 and part_break_remaining <= 0.0",
    "if remaining_after_tick > 0.0:",
    "if combo_retains_lock:",
    "return RESPAWN_WAIT", "return RESPAWN_RETRY", "return RESPAWN_RESET",
):
    assert source_token in life, source_token
assert "const RESPAWN_WAIT: int = 0" in life
assert "const RESPAWN_RETRY: int = 1" in life
assert "const RESPAWN_RESET: int = 2" in life

def section(start: str, end: str) -> str:
    assert main.count(start) == 1, start
    return main.split(start, 1)[1].split(end, 1)[0]

motion = section("func _advance_target_motion(delta: float) -> void:",
                 "func _begin_test_down()")
for token in (
    'enemy_shooter.call("warning_in_progress")',
    "TARGET_LIFECYCLE.movement_frozen(",
    "target_move_enabled, warning, target_hp, stagger_remaining,",
    "part_break_remaining, down_remaining, training_ko_remaining)",
    'target_motion.call("advance", delta, target.position,',
    "target_floor_mark.position = Vector3(",
):
    assert token in motion, token
assert motion.index('enemy_shooter.call("warning_in_progress")') < motion.index(
    "TARGET_LIFECYCLE.movement_frozen(") < motion.index(
    'target_motion.call("advance", delta, target.position,')

fx = section("func _advance_hit_fx(delta: float) -> void:",
             "func _tick_target_respawn(delta: float) -> void:")
assert 'hit_burst.call("advance", delta)' in fx
assert 'HIT_FX_PRESENTATION.present_incoming_damage_popup(' in fx
assert "_tick_target_respawn(delta)" in fx
assert fx.index('HIT_FX_PRESENTATION.present_incoming_damage_popup(') < fx.index(
    "_tick_target_respawn(delta)")
tick = section("func _tick_target_respawn(delta: float) -> void:",
               "func _reset_target_after_respawn() -> void:")
for token in (
    "if target_respawn_remaining <= 0.0:",
    "return",
    "target_respawn_remaining = COMBAT_TIMERS.remaining_after_delta(",
    "target_respawn_remaining <= 0.0 and _combo_lock_retention_active()",
    "TARGET_LIFECYCLE.respawn_action(",
    "if action == TARGET_LIFECYCLE.RESPAWN_RETRY:",
    "target_respawn_remaining = 0.01",
    "elif action == TARGET_LIFECYCLE.RESPAWN_RESET:",
    "_reset_target_after_respawn()",
):
    assert token in tick, token
assert tick.index("if target_respawn_remaining <= 0.0:") < tick.index(
    "target_respawn_remaining = COMBAT_TIMERS.remaining_after_delta(")
assert tick.index("target_respawn_remaining = COMBAT_TIMERS.remaining_after_delta(") < tick.index(
    "TARGET_LIFECYCLE.respawn_action(")
assert tick.index("TARGET_LIFECYCLE.respawn_action(") < tick.index(
    "if action == TARGET_LIFECYCLE.RESPAWN_RETRY:")
reset = section("func _reset_target_after_respawn() -> void:",
                "func _update_enemy_fire_eligibility() -> void:")
for token in (
    "target_hp = TARGET_MAX_HP",
    "target_respawn_remaining = 0.0",
    'target_parts.call("reset_parts")',
    'locked_target_part_id = ""',
    "auto_lock_initialized = false",
    'auto_lock_pending_part = ""',
    "auto_lock_pending_elapsed = 0.0",
    "manual_part_lock_active = not auto_lock_enabled",
    'enemy_shooter.call("set_head_destroyed", false)',
    "stagger_value = 0.0",
    "stagger_remaining = 0.0",
    "part_break_remaining = 0.0",
    "_refresh_hp_bar()",
):
    assert token in reset, token
assert main.count('target_parts.call("reset_parts")') == 1
assert main.count("target_hp = TARGET_MAX_HP") == 1

ko = section("func _tick_training_ko(delta: float) -> void:",
             "func _advance_target_motion(delta: float) -> void:")
assert "target_motion = TARGET_MOTION_SCRIPT.new()" in ko
assert "player.reset_physics_interpolation()" in ko
assert "target.reset_physics_interpolation()" in ko
assert "_reset_target_after_respawn()" in ko
assert ko.index("target_motion = TARGET_MOTION_SCRIPT.new()") < ko.index(
    "_reset_target_after_respawn()")

fire = section("func _update_enemy_fire_eligibility() -> void:",
               "func _input(event: InputEvent) -> void:")
for token in (
    "if enemy_shooter != null:",
    'enemy_shooter.set("can_fire", TARGET_LIFECYCLE.fire_allowed(',
    "target_hp, player_hp, stagger_remaining, part_break_remaining))",
):
    assert token in fire, token
physics = section("func _physics_process(delta: float) -> void:",
                  "func _process(delta: float) -> void:")
assert "_tick_target_recovery_timers(delta)" in physics
assert "_update_enemy_fire_eligibility()" in physics
assert "if down_remaining > 0.0:" in physics
assert physics.index("_tick_target_recovery_timers(delta)") < physics.index(
    "_update_enemy_fire_eligibility()") < physics.index(
    "if down_remaining > 0.0:")
print("SERA_TARGET_LIFECYCLE_STATIC_PASS")
