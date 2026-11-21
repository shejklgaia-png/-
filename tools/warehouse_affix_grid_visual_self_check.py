#!/usr/bin/env python3
"""SERA: visible craft stats, full seven-slot hanger, two-column 5-affix cards."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
ui = (root / "scripts/base_facility_system.gd").read_text("utf-8")
grid = (root / "scripts/sera_warehouse_grid.gd").read_text("utf-8")
table = (root / "scripts/sera_warehouse_stats_table.gd").read_text("utf-8")
ci = (root / "tools/sera_ci_manifest.txt").read_text("utf-8")
for token in (
    'info.replace("基礎ステータス（現行Aセット参照） / ", "")',
    '"font_size", 17 if key.begins_with("LockedCraftSlot_") else 20)',
    'Color("#e0f4f6")',
    'hanger.name = "WarehouseHangerTabs"',
    'tab.text = ""',
    'caption.name = "HangerCaption"',
    'caption.text = _slot_tab_caption(slot)',
    'caption.mouse_filter = Control.MOUSE_FILTER_IGNORE',
    'tab.clip_contents = true',
):
    assert token in ui, token
for token in (
    'const MAX_POOL_CARDS: int = 32',
    'effects.name = "ItemEffects"',
    'effects_right.name = "ItemEffectsRight"',
    'center_rule.name = "EffectCenterDivider"',
    'center_rule.color = Color("#55798a")',
    'var clean_effects: Array = Affixes.sanitize(entry.get("affixes", []))',
    'left_labels.append(Affixes.label(clean_effects[i]))',
    'right_labels.append(Affixes.label(clean_effects[i]))',
    'center_rule.visible = clean_effects.size() > 3',
):
    assert token in grid, token
for token in (
    'style.bg_color = Color("#152e3a")',
    '21 if compact and col == 2 else',
    '23 if col == 2 else',
):
    assert token in table, token
assert 'Color("#1b3541") if col == 2' not in table
assert 'Color("#112936")' not in table
assert 'py tools/warehouse_affix_grid_visual_self_check.py' in ci
assert 'gd tools/warehouse_affix_grid_visual_runtime_check.gd' in ci
print("SERA_WAREHOUSE_AFFIX_GRID_VISUAL_STATIC_PASS")
