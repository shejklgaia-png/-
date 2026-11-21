#!/usr/bin/env python3
"""NEXUS CUSTOMIZE top aggregate: live equipped stats, adaptivity and zero filtering."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
nexus = (root / "scripts/command_nexus.gd").read_text(encoding="utf-8")
stats = (root / "scripts/sera_nexus_stat_rows.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
for required in (
    'const EquipmentStatRows = preload("res://scripts/sera_nexus_stat_rows.gd")',
    'customize_stats_scroll = ScrollContainer.new()',
    'hud.add_child(customize_stats_scroll)',
    '"StatColumnRule"',
    'customize_total_column_rules.append(StatUI.new_column_rule(',
    'StatUI.layout_column_rules(customize_total_column_rules,',
    'StatUI.clear_cell_background(cell)',
    'StatUI.style_stat_labels(',
    'StatUI.fit_label(',
    'customize_stats_grid.columns = 3',
    'columns: int = 3 if inner_width >= 590.0',
    'customize_stats_grid.columns =',
    'func _refresh_customization_stats() -> void:',
    'EquipmentStatRows.from_selection(selected)',
    '_refresh_customization_stats()',
    'var show: bool = focused_target == "CUSTOMIZE"',
    'customize_stats_panel.visible = show',
    'customize_stats_scroll.visible = show',
):
    assert required in nexus, required
for required in (
    'const PartStats = preload("res://scripts/sera_part_stats.gd")',
    'static func from_selection(selected: Dictionary) -> Array[Dictionary]:',
    'static func from_stats(stats: Dictionary) -> Array[Dictionary]:',
    'if is_zero_approx(amount):',
    '"ATK EN"',
):
    assert required in stats, required
assert 'py tools/nexus_equipment_stats_self_check.py' in manifest
assert 'gd tools/nexus_equipment_stats_runtime_check.gd' in manifest
print("NEXUS_EQUIPMENT_STATS_STATIC_PASS")
