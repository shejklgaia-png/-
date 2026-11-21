#!/usr/bin/env python3
"""NEXUS/LABO shared visual language without changing navigation or save semantics."""
from pathlib import Path
r = Path(__file__).resolve().parents[1]
n = (r / "scripts/command_nexus.gd").read_text(encoding="utf-8")
l = (r / "scripts/sera_labo_round_skin.gd").read_text(encoding="utf-8")
manifest = (r / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
for expected in (
    'const LaboSkin = preload("res://scripts/sera_labo_round_skin.gd")',
    'hud.theme = LaboSkin.common_theme()',
    'func _apply_labo_typography() -> void:',
    'LaboSkin.tracked_display_font()',
    'LaboSkin.stats_font()',
    'LaboSkin.equipment_font()',
    'LaboSkin.ui_font()',
    'LaboSkin.card_style("normal")',
    'LaboSkin.card_style("selected" if system_selected_slot == slot else "normal")',
    'LaboSkin.terminal_segment_style("selected")',
    'LaboSkin.terminal_segment_style("normal")',
    # Seven installed-name buttons replace old icon/name/model-code columns.
    'var button := Button.new()',
    'button.text = _default_part_name(slot, selected_model)',
    'func _default_part_name(slot: String, model: String) -> String:',
    'func _show_customization_part_picker(slot: String) -> void:',
    'customize_part_grid.columns = 3',
    '"CustomizeSinglePartPreview"',
    '"CustomizePartPickerScroll"',
    'func _tap_equipment_control(point: Vector2) -> bool:',
    'func _tap_training_control(point: Vector2) -> bool:',
    'func _tap_system_control(point: Vector2) -> void:',
    'func _tap_archive_record(point: Vector2) -> void:',
    'func _tap_deployment_boss(point: Vector2) -> void:',
    'func _navigate_back() -> void:',
    'func _enter_base() -> void:',
):
    assert expected in n, expected
assert 'PrototypeCatalog.display_instance(' not in n, "model code must not be appended to item name"
assert 'var icon_size: float = minf(48.0, row.size.y - 18.0)' not in n, (
    "obsolete 48px icon would still be too small")
for expected in (
    'static func common_theme() -> Theme:',
    'static func card_style(',
    'static func terminal_segment_style(',
    'static func tracked_display_font()',
):
    assert expected in l, expected
assert 'run/main_scene="res://scenes/base_exploration.tscn"' in (
    r / "project.godot").read_text(encoding="utf-8")
assert 'py tools/nexus_labo_visual_self_check.py' in manifest
assert 'gd tools/nexus_labo_visual_runtime_check.gd' in manifest
print("NEXUS_LABO_VISUAL_STATIC_PASS")
