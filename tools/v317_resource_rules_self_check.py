#!/usr/bin/env python3
"""SERA v317 Stage 6: EN/SH pure rules, state ownership and numeric contracts."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
module = (root / "scripts/sera_resource_rules.gd").read_text(encoding="utf-8")
assert 'const RESOURCE_RULES = preload("res://scripts/sera_resource_rules.gd")' in main
assert "extends RefCounted" in module
for name in ("energy_spend", "next_recovery_pause", "recovered_energy",
             "recovered_shield", "exhaustion_unlocked"):
    assert f"static func {name}(" in module, name
    assert f"RESOURCE_RULES.{name}(" in main, name

spend = main.split("func _spend_energy(amount: float) -> bool:", 1)[1].split(
    "func _tick_resources(delta: float) -> void:", 1)[0]
for token in (
    "if amount <= 0.0:",
    "return true",
    "RESOURCE_RULES.energy_spend(",
    "energy, energy_exhausted, amount, 0.0001)",
    'if not bool(state["allowed"]):',
    'if bool(state["trigger_exhaustion"]):',
    "_enter_energy_exhaustion()",
    'energy = float(state["remaining"])',
    "energy_recovery_pause = 0.25",
):
    assert token in spend, token
assert spend.index("if amount <= 0.0:") < spend.index("RESOURCE_RULES.energy_spend(")
assert spend.index("if not bool(state[\"allowed\"]):") < spend.index(
    'energy = float(state["remaining"])')

tick = main.split("func _tick_resources(delta: float) -> void:", 1)[1].split(
    "func _take_test_damage(", 1)[0]
for token in (
    "energy_recovery_pause = RESOURCE_RULES.next_recovery_pause(",
    "shield_recovery_pause = RESOURCE_RULES.next_recovery_pause(",
    "energy = RESOURCE_RULES.recovered_energy(",
    "energy, energy_recovery_pause, delta, TEST_EN_MAX, 24.0)",
    "shield = RESOURCE_RULES.recovered_shield(",
    "shield, shield_recovery_pause, guard_break_remaining, down_remaining,",
    "delta, TEST_SH_MAX, 16.0)",
    "RESOURCE_RULES.exhaustion_unlocked(",
    "energy_exhausted, energy, TEST_EN_MAX, EN_RECOVERY_UNLOCK_RATIO",
    "energy_exhausted = false",
    "_refresh_player_hp_bar()",
    "_refresh_numeric_status_hud()",
):
    assert token in tick, token
numeric=main.split("func _refresh_numeric_status_hud() -> void:",1)[1].split(
    "func _take_test_damage(",1)[0]
view=(root/"scripts/sera_numeric_hud.gd").read_text(encoding="utf-8")
assert 'resources_label.text = NUMERIC_HUD.defense_shield_text(' in numeric
assert 'core_label.text = NUMERIC_HUD.target_lock_text(' in numeric
assert 'target_parts.call("get_part_integrity", locked_target_part_id)' in numeric
assert '"DEF %d%%  SH %d"' in view
assert '"LOCK %s  %d/%d  STAGGER %d/50  %s"' in view
assert tick.index("energy_recovery_pause =") < tick.index("energy = RESOURCE_RULES.recovered_energy(")
assert tick.index("shield_recovery_pause =") < tick.index("shield = RESOURCE_RULES.recovered_shield(")
assert tick.index("energy = RESOURCE_RULES.recovered_energy(") < tick.index(
    "RESOURCE_RULES.exhaustion_unlocked(")
for token in (
    "const TEST_EN_MAX: float = 100.0",
    "const TEST_SH_MAX: float = 100.0",
    "const EN_RECOVERY_UNLOCK_RATIO: float = 0.60",
    "var energy_exhausted: bool = false",
    "var shield_recovery_pause: float = 0.0",
):
    assert token in main, token
for token in (
    "if amount <= 0.0:",
    "if exhausted:",
    "if current_energy + epsilon < amount:",
    "current_energy <= epsilon",
    "maxf(0.0, current_energy - amount)",
    "maxf(0.0, pause - delta)",
    "minf(maximum, current_energy + per_second * delta)",
    "recovery_pause <= 0.0 and guard_break_remaining <= 0.0 and down_remaining <= 0.0",
    "minf(maximum, current_shield + per_second * delta)",
    "exhausted and current_energy >= maximum * unlock_ratio",
):
    assert token in module, token
for forbidden in ("get_tree(", "get_viewport(", "get_node(", "rig.call(", "part_stats", "touch_ui", "Label.new", "static var energy"):
    assert forbidden not in module, forbidden
# Explicit EN-consumption and special BOOST insufficient sliver remain in physics.
physics = main.split("func _physics_process(delta: float) -> void:", 1)[1]
assert "var boost_energy_ok: bool = _spend_energy(" in physics
assert "20.0 * delta * float(part_stats.get(\"energy_cost_mult\", 1.0))" in physics
assert "if not boost_energy_ok and not energy_exhausted:" in physics
assert "energy = 0.0" in physics and "_enter_energy_exhaustion()" in physics
assert "if energy_exhausted or not _spend_energy(6.0 * delta):" in physics
print("SERA_RESOURCE_RULES_STATIC_PASS")
