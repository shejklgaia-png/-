#!/usr/bin/env python3
"""SERA Stage15: numeric HUD output, exact prior precedence and tick ordering."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
hud = (ROOT / "scripts/sera_numeric_hud.gd").read_text(encoding="utf-8")
assert 'const NUMERIC_HUD = preload("res://scripts/sera_numeric_hud.gd")' in main
assert "extends RefCounted" in hud
for name in ("present_player_vitals", "present_target_health",
             "defense_shield_text", "target_lock_text", "step_speed_text",
             "step_detail_text"):
    assert f"static func {name}(" in hud, name
    assert f"NUMERIC_HUD.{name}(" in main, name
for forbidden in ("get_tree(", "get_node(", "get_viewport(", "static var ",
                  "FileAccess", "Label.new(", "ColorRect.new(", "part_stats",
                  "target_parts", "locked_target_part_id", "get_part_name"):
    assert forbidden not in hud, forbidden

def section(start: str, end: str) -> str:
    assert main.count(start) == 1, start
    return main.split(start, 1)[1].split(end, 1)[0]

vitals = section("func _refresh_player_hp_bar() -> void:",
                 "func _refresh_hp_bar() -> void:")
assert "NUMERIC_HUD.present_player_vitals(vitals_hud, player_hp," in vitals
assert 'float(part_stats.get("max_hp", 800.0)), energy, TEST_EN_MAX,' in vitals
assert "energy_exhausted)" in vitals
target = section("func _refresh_hp_bar() -> void:",
                 "func _clear_strike_tracking() -> void:")
assert "NUMERIC_HUD.present_target_health(" in target
assert "hp_label, hp_fill, target_hp, TARGET_MAX_HP, TARGET_HP_BAR_WIDTH)" in target

tick = section("func _tick_resources(delta: float) -> void:",
               "func _refresh_numeric_status_hud() -> void:")
order = (
    "energy_recovery_pause = RESOURCE_RULES.next_recovery_pause(",
    "shield_recovery_pause = RESOURCE_RULES.next_recovery_pause(",
    "energy = RESOURCE_RULES.recovered_energy(",
    "shield = RESOURCE_RULES.recovered_shield(",
    "RESOURCE_RULES.exhaustion_unlocked(",
    "energy_exhausted = false",
    "_refresh_player_hp_bar()",
    "_refresh_numeric_status_hud()",
)
assert [tick.index(x) for x in order] == sorted(tick.index(x) for x in order)
status = section("func _refresh_numeric_status_hud() -> void:",
                 "func _take_test_damage(")
for token in (
    "if resources_label != null:",
    "resources_label.text = NUMERIC_HUD.defense_shield_text(",
    'float(part_stats.get("defense", 0.16)), shield)',
    "if core_label != null:",
    'var label_name: String = "BODY"',
    "var integrity: float = float(target_hp)",
    "var maximum: float = float(TARGET_MAX_HP)",
    "if target_parts != null and not locked_target_part_id.is_empty():",
    'target_parts.call("get_part_name", locked_target_part_id)',
    'target_parts.call("get_part_integrity", locked_target_part_id)',
    'target_parts.call("get_part_max_integrity", locked_target_part_id)',
    "core_label.text = NUMERIC_HUD.target_lock_text(",
    "label_name, integrity, maximum, stagger_value,",
    "part_break_remaining, stagger_remaining, target_move_enabled)",
    "if target_parts_label != null and target_parts != null:",
    'var next_status: String = str(target_parts.call("status_line"))',
    "if target_parts_label.text != next_status:",
):
    assert token in status, token

step = section("func _refresh_step_status_ui() -> void:",
               "func _record_kick_debug(")
for token in (
    "if step_status_label == null or step_detail_label == null:",
    "step_status_label.text = NUMERIC_HUD.step_speed_text(",
    "step_speed_current, step_active, STEP_SPEED,",
    'float(part_stats.get("step_speed_mult", 1.0)))',
    "step_detail_label.text = NUMERIC_HUD.step_detail_text(",
    "back_somersault_active, landing_from_somersault, step_active,",
    "side_kick_active, side_kick_side, step_arc_length,",
    "kick_debug_remaining, kick_debug_text, step_has_last,",
    "step_traveled_distance, step_last_elapsed)",
):
    assert token in step, token
phys = section("func _physics_process(delta: float) -> void:",
               "func _refresh_combat_state_hud(")
assert "var next_speed_label: String = NUMERIC_HUD.step_speed_text(" in phys
assert "step_speed_current, false, STEP_SPEED," in phys
assert "if step_status_label.text != next_speed_label:" in phys
assert "_refresh_step_status_ui()" in phys
assert phys.index("thruster_presentation.update(rig, exhaust_on,") < phys.index(
    "var next_speed_label: String = NUMERIC_HUD.step_speed_text(") < phys.index(
    "if floor_stage != null:") < phys.index("_refresh_combat_state_hud(")

for token in (
    'hud.call("set_vitals", player_hp, player_max_hp, energy, energy_max, exhausted)',
    '"TARGET   %d / %d HP" % [target_hp, target_max_hp]',
    '"TARGET   DOWN / RESTARTING"',
    "Vector2(bar_width * float(target_hp) / float(target_max_hp), 7.0)",
    'Color("5de4d1") if float(target_hp) / float(target_max_hp) > 0.40',
    'else Color("ffb85d")',
    '"DEF %d%%  SH %d" % [roundi(defense * 100.0), ceili(shield)]',
    '"LOCK %s  %d/%d  STAGGER %d/50  %s"',
    '"DOWN" if part_break_remaining >= 3.0',
    '"BREAK" if part_break_remaining > 0.0',
    '"STUN" if stagger_remaining > 0.0',
    '"MOVE" if target_move_enabled else "HOLD"',
    '"STEP SPEED %.1fm/s" % display_speed',
    '"KICK B / BACK ARC 5.0m"',
    '"KICK B / LAND 0.2s"',
    '"KICK %s %.2fm planned"',
    '"STEP %.2fm planned" % step_arc_length',
    '"LAST %.2fm  /  %.2fs"',
    '"STEP ALL 5.0m"',
):
    assert token in hud, token
for order_tokens in (
    ("if back_somersault_active:", "if landing_from_somersault:",
     "if step_active:", "if kick_debug_remaining > 0.0:",
     "if step_has_last:"),
    ("if side_kick_active:", "if kick_debug_remaining > 0.0:"),
):
    assert [hud.index(x) for x in order_tokens] == sorted(hud.index(x) for x in order_tokens)
print("SERA_NUMERIC_HUD_STATIC_PASS")
