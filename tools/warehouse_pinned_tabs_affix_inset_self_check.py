#!/usr/bin/env python3
"""SERA warehouse: 6px inset for two-column effects and non-scrolling action tabs."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
ui = (root / "scripts/base_facility_system.gd").read_text(encoding="utf-8")
cards = (root / "scripts/sera_warehouse_grid.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
for token in (
    'actions_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO',
    'actions_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED',
    'item_layer.add_child(junk_button)',
    'item_layer.add_child(grid)',
    'item_layer.add_child(grid)\\n        grid.name = "WarehouseEquipment"',
    'junk_button.pressed.connect(_confirm_bulk_junk_deletion)',
    '_configure_page_scroll(80 if section == "materials" else 140)',
    'hanger.name = "WarehouseHangerTabs"',
    'switcher.name = "WarehouseCategoryTabs"',
):
    assert token in ui, token
assert 'modal_actions.add_child(junk_button)' not in ui
for token in (
    'effects.position = Vector2(22.0, 101.0)',
    'effects.size = Vector2(maxf(32.0, middle_x - 30.0)',
    'effects_right.position = Vector2(middle_x + 14.0, 101.0)',
    '_card_width - middle_x - 30.0',
    'center_rule.color = Color("#55798a")',
    'center_rule.size = Vector2(2.0, _card_height() - 118.0)',
    'const MAX_POOL_CARDS: int = 32',
):
    assert token in cards, token
assert 'py tools/warehouse_pinned_tabs_affix_inset_self_check.py' in manifest
assert 'gd tools/warehouse_pinned_tabs_affix_inset_runtime_check.gd' in manifest
print("SERA_WAREHOUSE_PINNED_TABS_AFFIX_INSET_STATIC_PASS")
