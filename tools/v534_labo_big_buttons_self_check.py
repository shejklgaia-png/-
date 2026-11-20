#!/usr/bin/env python3
"""LABO large touch-target specification: all pages, no horizontal part scroll."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
ui = (root / "scripts/base_facility_system.gd").read_text(encoding="utf-8")
warehouse = (root / "scripts/sera_warehouse_grid.gd").read_text(encoding="utf-8")
material = (root / "ui/labo/LaboMaterialCard.tscn").read_text(encoding="utf-8")
equipment = (root / "ui/labo/LaboEquipmentCard.tscn").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
for anchor in ("LABO_NAV_HEIGHT", "LABO_SLOT_HEIGHT", "LABO_BACK_HEIGHT",
               "LABO_CONFIRM_HEIGHT", "LABO_CRAFT_CARD_HEIGHT",
               "LABO_CONVERSION_HEIGHT", "MATERIAL_CARD_HEIGHT",
               "b.custom_minimum_size = Vector2(0, LABO_SLOT_HEIGHT)",
               "tab.custom_minimum_size = Vector2(0, LABO_SLOT_HEIGHT)",
               '"CraftSlotTabs"', '"WarehouseHangerTabs"'):
    assert anchor in ui, anchor
assert '"CraftSlotScroll"' not in ui and '"WarehouseHangerScroll"' not in ui
assert "CARD_HEIGHT_MATERIALS: float = 120.0" in warehouse
assert "CARD_HEIGHT_EQUIPMENT: float = 180.0" in warehouse
assert "theme_override_font_sizes/font_size = 16" in material
assert "theme_override_font_sizes/font_size = 18" in equipment
assert "gd tools/v534_labo_big_buttons_runtime_check.gd" in manifest
assert "py tools/v534_labo_big_buttons_self_check.py" in manifest
print("SERA_V534_LABO_BIG_BUTTONS_STATIC_PASS")
