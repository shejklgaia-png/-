#!/usr/bin/env python3
"""v538: LABO's top-left suspended English navigation spec."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
ui = (root / "scripts/base_facility_system.gd").read_text(encoding="utf-8")
skin = (root / "scripts/sera_labo_round_skin.gd").read_text(encoding="utf-8")
ci = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
for name in ('"EQUIPMENT"', '"REFINERY"', '"STORAGE"'):
    assert name in ui, name
for anchor in ('section_tabs.name = "FacilitySectionTabs"',
               'modal.add_child(section_tabs)',
               'section_tabs.position = Vector2.ZERO',
               'LaboSkin.hanging_tab_style(', 'section_tabs.get_children()',
               'section_tabs.size = Vector2(', 'Control.SIZE_SHRINK_BEGIN',
               'button.mouse_filter = Control.MOUSE_FILTER_STOP'):
    assert anchor in ui, anchor
assert 'body.add_child(section_tabs)' not in ui
assert 'body.move_child(section_tabs,' not in ui
for anchor in ('static func hanging_tab_style(', 'StyleBoxTexture.new()',
               'Image.create(64, 64', 'var inset: int ='):
    assert anchor in skin, anchor
assert 'py tools/v538_hanging_nav_self_check.py' in ci
assert 'gd tools/v538_hanging_nav_runtime_check.gd' in ci
print("SERA_V538_HANGING_NAV_STATIC_PASS")
