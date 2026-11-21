#!/usr/bin/env python3
"""SERA v544: visibly differentiated LAB typography."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
ui=(root/"scripts/base_facility_system.gd").read_text(encoding="utf-8")
skin=(root/"scripts/sera_labo_round_skin.gd").read_text(encoding="utf-8")
wh=(root/"scripts/sera_warehouse_grid.gd").read_text(encoding="utf-8")
manifest=(root/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
for token in ('static func tracked_display_font() -> FontVariation:',
              'static func tracked_data_font() -> FontVariation:',
              '_tracked_display.base_font = display_font()',
              '_tracked_data.base_font = data_font()',
              '_tracked_display.spacing_glyph = 1',
              '_tracked_data.spacing_glyph = 1'):
    assert token in skin, token
for token in ('modal_title.add_theme_font_size_override("font_size", 32)',
              'module_caption.add_theme_font_size_override("font_size", 14)',
              'button.add_theme_font_override("font", LaboSkin.tracked_display_font())',
              'return 20 if width < 540.0 else 23 if width < 720.0 else 24',
              '28 if get_viewport().get_visible_rect().size.x >= 500.0 else 24',
              'Color("#8da9b5") if key.begins_with("LockedCraftSlot_")',
              '"font_size", 17 if key.begins_with("LockedCraftSlot_") else 20)',
              'grade_tag.add_theme_font_size_override("font_size", 12)',
              'module_status.visible = get_viewport().get_visible_rect().size.x >= 580.0'):
    assert token in ui, token
for token in ('meta.add_theme_font_override("font", LaboSkin.tracked_data_font())',
              'empty.add_theme_font_override("font", LaboSkin.tracked_display_font())',
              'empty.add_theme_font_size_override("font_size", 17)',
              'title.add_theme_font_size_override("font_size", 20)',
              'effects.add_theme_font_size_override("font_size", 14)',
              'MAX_POOL_CARDS: int = 32',
              'virtual_slots = (999 if mode == "equipment"'):
    assert token in wh, token
assert 'PrototypeBasePreview' not in ui
assert 'py tools/v544_labo_type_hierarchy_self_check.py' in manifest
assert 'gd tools/v544_labo_type_hierarchy_runtime_check.gd' in manifest
print("SERA_V544_LABO_TYPE_HIERARCHY_STATIC_PASS")
