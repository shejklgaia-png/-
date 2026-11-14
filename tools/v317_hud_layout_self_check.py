#!/usr/bin/env python3
"""Stage16: compact combat HUD construction is layout-only, not gameplay."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
layout = (ROOT / "scripts/sera_hud_layout.gd").read_text(encoding="utf-8")
assert "extends RefCounted" in layout
assert 'const HUD_LAYOUT = preload("res://scripts/sera_hud_layout.gd")' in main
for name in ("build_panel", "build_primary_status", "build_step_telemetry"):
    assert f"static func {name}(" in layout, name
    assert f"HUD_LAYOUT.{name}(" in main, name
for forbidden in ("get_tree(", "get_node(", "get_viewport(", "get_global_rect(",
                  "static var ", "_input(", "physics_process", "Gesture",
                  "player_hp: float", "target_hp: int", "energy_exhausted: bool",
                  "controller_contains", "Callable(", "connect("):
    assert forbidden not in layout, forbidden

def section(start: str, stop: str) -> str:
    assert main.count(start) == 1, start
    return main.split(start, 1)[1].split(stop, 1)[0]

overlay = section("func _build_overlay() -> void:",
                  "func _build_lock_switch_buttons(layer: CanvasLayer) -> void:")
required = [
    'layer.name = "HUD"',
    "touch_ui = UI_SCRIPT.new()",
    "_build_lock_switch_buttons(layer)",
    "_update_melee_lock_marker()",
    "hud_panel = HUD_LAYOUT.build_panel(layer)",
    'nexus_button.name = "ReturnToNexus"',
    'nexus_button.pressed.connect(_request_return_to_nexus)',
    "var primary_widgets: Dictionary = HUD_LAYOUT.build_primary_status(",
    "hud_panel, CombatVitals, TARGET_HP_BAR_WIDTH)",
    'state_label = primary_widgets["state"]',
    'hp_label = primary_widgets["target_hp_label"]',
    'hp_fill = primary_widgets["target_hp_fill"]',
    'vitals_hud = primary_widgets["vitals"]',
    "_refresh_player_hp_bar()",
    'damage_label.name = "DamagePopup"',
    "_refresh_hp_bar()",
    "resources_label = Label.new()",
    "core_label = Label.new()",
    "target_parts_label = Label.new()",
    'diagnostic_overlay.name = "DiagnosticPanel"',
    "_tick_resources(0.0)",
    "var step_widgets: Dictionary = HUD_LAYOUT.build_step_telemetry(hud_panel)",
    'step_status_label = step_widgets["status"]',
    'step_detail_label = step_widgets["detail"]',
    "_refresh_step_status_ui()",
    'projectile_hit_overlay.name = "ProjectileHitTint"',
    "enemy_debug_ui = ENEMY_DEBUG_SCRIPT.new()",
    'enemy_debug_ui.connect("attack_selected", Callable(enemy_shooter, "set_attack_type"))',
]
for token in required:
    assert token in overlay, token
assert [overlay.index(x) for x in required] == sorted(overlay.index(x) for x in required)
assert "hud_panel = Panel.new()" not in main
assert "state_label = Label.new()" not in main
assert "hp_fill = ColorRect.new()" not in main
assert "step_status_label = Label.new()" not in main
assert "step_detail_label = Label.new()" not in main
for exact in (
    'panel.name = "CompactCombatHUD"',
    "panel.mouse_filter = Control.MOUSE_FILTER_IGNORE",
    "panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)",
    "panel.offset_left = 18.0", "panel.offset_right = -18.0",
    "panel.offset_top = 26.0", "panel.offset_bottom = 150.0",
    'accent_bar.name = "Accent"', 'heading.name = "CombatTitle"',
    'heading.text = "SERA   /   LOCK"',
    "heading.position = Vector2(27.0, 10.0)",
    'state_label.name = "ActionState"',
    'state_label.text = "WAIT  |  Wait_motion"',
    'hp_label.name = "TargetHpLabel"',
    "hp_label.position = Vector2(414.0, 80.0)",
    'bar_background.name = "TargetHpBackground"',
    "bar_background.size = Vector2(hp_bar_width, 7.0)",
    'hp_fill.name = "TargetHpFill"',
    "hp_fill.position = bar_background.position",
    "var vitals_hud: Control = vitals_script.new()",
    'vitals_hud.name = "CombatVitals"',
    "vitals_hud.position = Vector2(27.0, 62.0)",
    "vitals_hud.size = Vector2(190.0, 61.0)",
    'step_status_label.name = "StepStatusLabel"',
    "step_status_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)",
    "step_status_label.offset_left = -224.0",
    "step_status_label.offset_right = -18.0",
    "step_status_label.offset_top = 14.0",
    "step_status_label.offset_bottom = 50.0",
    'step_detail_label.name = "StepModeDetails"',
    "step_detail_label.offset_left = -250.0",
    "step_detail_label.offset_top = 60.0",
    'control_hint.name = "InputHint"',
    'control_hint.text = ""',
    "control_hint.offset_top = 94.0",
):
    assert exact in layout, exact
assert layout.index('heading.name = "CombatTitle"') < layout.index(
    'state_label.name = "ActionState"') < layout.index(
    'vitals_hud.name = "CombatVitals"') < layout.index(
    'step_status_label.name = "StepStatusLabel"')
assert layout.count("return {") == 2
for name in ("state", "target_hp_label", "target_hp_fill", "vitals",
             "status", "detail"):
    assert f'"{name}":' in layout
# The gesture exclusion and button callback ownership remain entirely in main.
button = section("func _pointer_on_step_hud(pos: Vector2) -> bool:",
                 "func _update_equipped_collision_height() -> void:")
assert "hud_panel.get_global_rect().has_point(pos)" not in button
assert "handedness_button.get_global_rect().has_point(pos)" in button
assert "enemy_debug_ui.find_children(" in button
assert 'nexus_button.mouse_filter = Control.MOUSE_FILTER_IGNORE' in main
assert 'handedness_button = Button.new()' not in main
assert 'rig.call("set_run_left_handed", left_handed)' in main
assert 'hud_panel.visible = false' in main
assert 'clean_training_hud = CLEAN_TRAINING_HUD.new()' in main
assert '_pointer_on_nexus_button(event.position)' in main
print("SERA_HUD_LAYOUT_STATIC_PASS")
