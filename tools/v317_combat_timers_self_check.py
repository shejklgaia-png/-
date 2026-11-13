#!/usr/bin/env python3
"""v317 Stage7: combat timer extraction keeps physics order and side effects."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
timers = (root / "scripts/sera_combat_timers.gd").read_text(encoding="utf-8")
assert 'const COMBAT_TIMERS = preload("res://scripts/sera_combat_timers.gd")' in main
for token in (
    "extends RefCounted",
    "static func remaining_after_delta(remaining: float, delta: float) -> float:",
    "return maxf(0.0, remaining - delta)",
    "static func stagger_after_countdown(",
    "if stagger_remaining <= 0.0:",
    "return maxf(0.0, value - decay_rate * delta)",
):
    assert token in timers, token
for forbidden in (
    "get_tree(", "get_node(", "get_viewport(", "main.gd",
    "rig.call(", "touch_ui", "target_parts", "static var",
):
    if forbidden == "main.gd":
        continue  # module comment documents ownership of main.gd
    assert forbidden not in timers, forbidden

combo = main.split("func _tick_combo_window_timers(delta: float) -> void:", 1)[1].split(
    "func _tick_target_recovery_timers(", 1)[0]
for token in (
    "bash_followup_window_remaining = COMBAT_TIMERS.remaining_after_delta(",
    "bash_loop_window_remaining = COMBAT_TIMERS.remaining_after_delta(",
    "if kick_debug_remaining > 0.0:",
    "kick_debug_remaining = COMBAT_TIMERS.remaining_after_delta(",
    "if kick_debug_remaining == 0.0:",
    "_refresh_step_status_ui()",
):
    assert token in combo, token
assert combo.index("if kick_debug_remaining > 0.0:") < combo.index(
    "kick_debug_remaining = COMBAT_TIMERS.remaining_after_delta(")
assert combo.index("if kick_debug_remaining == 0.0:") < combo.index("_refresh_step_status_ui()")
recovery = main.split("func _tick_target_recovery_timers(delta: float) -> void:", 1)[1].split(
    "func _physics_process(", 1)[0]
for token in (
    "stagger_remaining = COMBAT_TIMERS.remaining_after_delta(",
    "part_break_remaining = COMBAT_TIMERS.remaining_after_delta(",
    "stagger_value = COMBAT_TIMERS.stagger_after_countdown(",
    "stagger_value, stagger_remaining, delta, 8.0)",
):
    assert token in recovery, token
assert recovery.index("stagger_remaining =") < recovery.index("stagger_value =")

physics = main.split("func _physics_process(delta: float) -> void:", 1)[1].split(
    "func _process(", 1)[0]
# Explicit ordering contract: KO early exit > combo windows > input
# > EN/SH update > stagger/break > shooter > reaction lock countdown.
# KO mode also calls _tick_resources; inspect the normal physics path
# only after the early-return branch and verify the actual execution order.
early = physics.split("    _tick_combo_window_timers(delta)", 1)[0]
assert early.index("_tick_training_ko(delta)") < early.index(
    "if training_ko_remaining > 0.0:")
assert "        _tick_resources(delta)" in early
assert "        return" in early
normal = physics.split("    _tick_combo_window_timers(delta)", 1)[1]
ordered = [
    "    _update_guard_hold()",
    "    var was_energy_exhausted: bool = energy_exhausted",
    "    _tick_resources(delta)",
    "    _tick_target_recovery_timers(delta)",
    'enemy_shooter.set("can_fire",',
    "    if down_remaining > 0.0:",
    "down_remaining = COMBAT_TIMERS.remaining_after_delta(down_remaining, delta)",
    "    if guard_break_remaining > 0.0:",
    "guard_break_remaining = COMBAT_TIMERS.remaining_after_delta(guard_break_remaining, delta)",
    "    if damage_reaction_active:",
]
indices = [normal.index(x) for x in ordered]
assert indices == sorted(indices), indices
assert "if down_remaining <= 0.0:" in physics
assert "energy = TEST_EN_MAX\n            shield = TEST_SH_MAX\n            energy_exhausted = false" in physics
assert "if guard_break_remaining <= 0.0 and down_remaining <= 0.0" in physics
assert 'rig.call("finish_damage", false)' in physics
assert "if hit_stop_remaining <= 0.0:" in physics.split("_tick_combo_window_timers(delta)")[0]
print("SERA_COMBAT_TIMERS_STATIC_PASS")
