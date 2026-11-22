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
    'StatUI.layout_metric_pair(',
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
    'static func from_stats(stats: Dictionary,',
    'if is_zero_approx(amount):',
    '"攻撃EN消費"',
    '"重量"',
    '"group": group',
    '"en_recovery_per_second"',
):
    assert required in stats, required
for label in (
    "重量", "EN回復", "追尾", "攻撃速度",
    "耐久力", "防御", "ダメージ", "破壊", "怯み",
    "攻撃EN消費", "走行速度", "ブースト速度", "ロック距離",
    "ガード防御", "ステップ速度", "バッシュダメージ",
    "バッシュ破壊", "ガード移行",
):
    assert label in stats, label
for obsolete in ('"WEIGHT "', '"EN OUTPUT"', '"TRACK"', '"ATK SPEED"',
                 '"DEF"', '"ATK1"', '"BRK1"', '"STG1"', '"RUN"',
                 '"BOOST"', '"LOCK"', '"GUARD"', '"EN COST"', '"STEP"',
                 '"BASH"', '"CHARGE"'):
    assert obsolete not in stats, obsolete
# 720x1280 CUSTOMIZE: two-tier stat typography, rather than cramped side-by-side.
for required in (
    'customize_stats_grid.add_theme_constant_override("v_separation", 1)',
    'var cell_height: float = 44.0',
    'var height: float = minf(view.y * 0.227, 290.0)',
    'StatUI.layout_metric_pair(label, value, cell_width, cell_height, 19, 25, 16, 20)',
    'customize_weapon_divider',
    'customize_stats_scroll.get_v_scroll_bar().value_changed.connect(',
    'customize_weapon_first_index',
):
    assert required in nexus, required
stat_layout = (root / "scripts/sera_status_column_ui.gd").read_text(encoding="utf-8")
assert 'static func layout_metric_pair(' in stat_layout
assert 'get_string_size(' in stat_layout
assert 'static func semantic_stat_lines(' in stat_layout
assert 'name_label.autowrap_mode = TextServer.AUTOWRAP_OFF' in stat_layout
assert 'name_label.text = semantic_stat_lines(' in stat_layout
assert 'name_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY' not in stat_layout
for name in ("ブースト速度倍率", "被弾時間倍率", "被弾後退倍率",
             "部位モデル区分", "ダウン被弾回数", "歩行モーション",
             "ガードEN消費倍率", "特性 "):
    assert name in stat_layout, name
assert 'StatUI.status_window_style()' in nexus
assert 'return from_stats(PartStats.build(selected), selected)' in stats
assert 'static func _average(' in stats
assert '"%.1f" % amount' in stats
assert '"チャージ威力"' not in stats
assert 'StatUI.attach_status_marks(' in nexus
assert 'StatUI.layout_status_marks(' in nexus
assert 'py tools/nexus_equipment_stats_self_check.py' in manifest
assert 'gd tools/nexus_equipment_stats_runtime_check.gd' in manifest
print("NEXUS_EQUIPMENT_STATS_STATIC_PASS")
