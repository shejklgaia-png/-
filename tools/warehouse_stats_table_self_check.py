#!/usr/bin/env python3
"""Warehouse detail: a three-column, numeric-aligned status table replaces prose."""
from pathlib import Path
r = Path(__file__).resolve().parents[1]
ui = (r/"scripts/base_facility_system.gd").read_text("utf-8")
popup = (r/"scripts/sera_warehouse_detail_popup.gd").read_text("utf-8")
stats = (r/"scripts/sera_labo_stats.gd").read_text("utf-8")
table = (r/"scripts/sera_warehouse_stats_table.gd").read_text("utf-8")
manifest = (r/"tools/sera_ci_manifest.txt").read_text("utf-8")
for token in (
    'const WarehouseStatsTable = preload("res://scripts/sera_warehouse_stats_table.gd")',
    'warehouse_detail_popup.open_item(entry)',
    'info.replace("基礎ステータス / ", "")',
):
    assert token in ui, token
for token in ('const StatTable = preload("res://scripts/sera_warehouse_stats_table.gd")',
              'var table: GridContainer = StatTable.build(', 'stats_container.add_child(table)',
              'WarehouseDetailStatsScroll'):
    assert token in popup, token
assert 'breakdown.name = "WarehouseStatsBreakdown"' not in ui
assert 'breakdown.text = LaboStats.total_formula' not in ui
for token in (
    'static func total_stat_rows(blueprint: String, effects: Variant) -> Array[Dictionary]:',
    '"name": Affixes.EFFECT_NAMES[key]',
    '"formula": formula',
    '"total": total',
):
    assert token in stats, token
assert '"注: 追加特性は戦闘計算へ未接続の試作値です。"' not in stats
for token in (
    'extends RefCounted',
    'static func build(blueprint: String, effects: Variant, viewport_width: float) -> GridContainer:',
    'table.name = "WarehouseStatsTable"',
    'table.columns = 3',
    'table.add_theme_constant_override("h_separation", 0)',
    'table.add_theme_constant_override("v_separation", 0)',
    'var headings: Array[String] = ["項目", "計算式", "合計"]',
    '"Stat_name_" + effect_id',
    '"Stat_formula_" + effect_id',
    '"Stat_total_" + effect_id',
    'horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT',
    'style.border_width_bottom = 1',
    'style.border_width_right = 1',
    'LaboSkin.stats_font()',
):
    assert token in table, token
assert 'py tools/warehouse_stats_table_self_check.py' in manifest
assert 'gd tools/warehouse_stats_table_runtime_check.gd' in manifest
print("SERA_WAREHOUSE_STATUS_TABLE_STATIC_PASS")
