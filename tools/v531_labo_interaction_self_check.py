#!/usr/bin/env python3
"""LABO v531: native scrolling, common confirmation, stat math, 3D and safe inventory."""
from pathlib import Path
p = Path(__file__).resolve().parents[1]
ui = (p/"scripts/base_facility_system.gd").read_text(encoding="utf-8")
save = (p/"scripts/sera_save.gd").read_text(encoding="utf-8")
stats = (p/"scripts/sera_labo_stats.gd").read_text(encoding="utf-8")
stage = (p/"scripts/labo_hero_stage.gd").read_text(encoding="utf-8")
grid = (p/"scripts/sera_warehouse_grid.gd").read_text(encoding="utf-8")
popup = (p/"scripts/sera_warehouse_detail_popup.gd").read_text(encoding="utf-8")
manifest = (p/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
for anchor in ('actions_scroll = LaboTouchScroll.new()',
               'scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO',
               '_new_grid("PrototypeGrid", 1)',
               'var slot_tabs := HBoxContainer.new()',
               'func _request_confirmation(',
               '_confirm_selected_prototype()', '_confirm_conversion.bind(rank)',
               'var stepper := HBoxContainer.new()', 'func _confirm_bulk_junk_deletion(',
               'func _mark_warehouse_item(', 'warehouse_detail_popup.open_item('):
    assert anchor in ui, anchor
assert 'var table: GridContainer = StatTable.build(' in popup
assert '"CraftSlotScroll"' not in ui, "all seven fixed part tabs must fit without horizontal scrolling"
for anchor in ('func set_prototype_mark(', 'func delete_junk_prototypes(',
               'func count_junk_prototypes(', 'not equipped.values().has',
               'updated["crafted_items"] = kept',
               'cleaned["favorite"]', 'cleaned["junk"]'):
    assert anchor in save, anchor
assert 'PartStats.PROFILES' in stats and 'static func baseline(' in stats
assert 'static func total_formula(' in stats
assert 'static func total_stat_rows(' in stats
for anchor in ('func _build_converter(', 'func _build_warehouse(',
               'func set_section(', 'converter_crystals',
               'printer_group.visible', 'warehouse_group.visible'):
    assert anchor in stage, anchor
assert 'const MAX_POOL_CARDS: int = 32' in grid
assert 'bool(entry.get("favorite", false))' in grid
assert "py tools/v531_labo_interaction_self_check.py" in manifest
assert "gd tools/v531_labo_interaction_runtime_check.gd" in manifest
print("SERA_V531_LABO_STATIC_PASS")
