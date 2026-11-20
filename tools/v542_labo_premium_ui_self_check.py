#!/usr/bin/env python3
"""SERA v542: unified premium industrial interface with shared cached skins."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
ui = (root / "scripts/base_facility_system.gd").read_text(encoding="utf-8")
skin = (root / "scripts/sera_labo_round_skin.gd").read_text(encoding="utf-8")
grid = (root / "scripts/sera_warehouse_grid.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
for token in ('FacilityModuleStrip', 'ModuleSignalRail', 'ModuleCaption',
              'ModuleStatus', '01 / SHELL FABRICATION', '02 / MATERIAL REFINERY',
              '03 / EQUIPMENT ARCHIVE', 'ExitKey', 'CardSignalRail',
              'CardSystemState', 'SCHEMATIC / AVAILABLE', 'ACCESS / LOCKED',
              'MaterialGradeTag', 'R1', 'R2', 'R3'):
    assert token in ui, token
for token in ('static func panel_style()', 'static func hanging_tab_style(',
              'static func card_style(', 'StyleBoxTexture.new()',
              '_panel_cache', '_card_cache', '_tab_cache',
              'Color("#9bf5ef")', 'Color("#9cf6f2")'):
    assert token in skin, token
assert 'get_viewport().get_visible_rect().size.y * 0.30' in ui
assert 'CRAFT_CATALOG_SLOTS: int = 20' in ui
assert 'PrototypeBasePreview' not in ui
assert 'SlotAddress' in grid and 'EmptyBeacon' in grid
assert 'MAX_POOL_CARDS: int = 32' in grid
assert 'virtual_slots = (999 if mode == "equipment"' in grid
assert 'marker.color = Color("#79b6c2")' in grid
assert 'tier_rail.color = Color("#79b6c2")' in ui
assert 'py tools/v542_labo_premium_ui_self_check.py' in manifest
assert 'gd tools/v542_labo_premium_ui_runtime_check.gd' in manifest
print("SERA_V542_LABO_PREMIUM_UI_STATIC_PASS")
