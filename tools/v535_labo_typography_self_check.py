#!/usr/bin/env python3
"""LABO v535: distinct JP display/data font and readable fixed-size controls."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
skin=(root/"scripts/sera_labo_round_skin.gd").read_text(encoding="utf-8")
fac=(root/"scripts/base_facility_system.gd").read_text(encoding="utf-8")
wh=(root/"scripts/sera_warehouse_grid.gd").read_text(encoding="utf-8")
mat=(root/"ui/labo/LaboMaterialCard.tscn").read_text(encoding="utf-8")
equip=(root/"ui/labo/LaboEquipmentCard.tscn").read_text(encoding="utf-8")
manifest=(root/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
for token in ("static func ui_font(", "static func title_font(",
              "static func data_font(", "SystemFont.new()", "Noto Sans JP",
              "Noto Sans CJK JP", "Roboto Mono", "theme.default_font =",
              "theme.default_font_size ="):
    assert token in skin,token
for token in ('body.move_child(section_tabs,', 'SectionHeaderAccent',
              'func _slot_font_size(', 'func _nav_font_size(',
              'LaboSkin.title_font()', 'LaboSkin.data_font()',
              'LABO_NAV_HEIGHT: float = 64.0',
              'LABO_SLOT_HEIGHT: float = 58.0',
              'LABO_BACK_HEIGHT: float = 66.0',
              'LABO_CRAFT_CARD_HEIGHT: float = 108.0',
              'MATERIAL_CARD_HEIGHT: float = 108.0'):
    assert token in fac,token
assert 'font_size = 19' in mat
assert 'font_size = 21' in equip
assert 'LaboSkin.ui_font()' in wh and 'LaboSkin.data_font()' in wh
assert '"CraftSlotScroll"' not in fac and '"WarehouseHangerScroll"' not in fac
assert 'py tools/v535_labo_typography_self_check.py' in manifest
assert 'gd tools/v535_labo_typography_runtime_check.gd' in manifest
print("SERA_V535_LABO_TYPOGRAPHY_STATIC_PASS")
