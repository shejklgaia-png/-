#!/usr/bin/env python3
"""SERA v540: card density, full virtual hanger, selected markers and matte gradients."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fac = (root / "scripts/base_facility_system.gd").read_text(encoding="utf-8")
grid = (root / "scripts/sera_warehouse_grid.gd").read_text(encoding="utf-8")
skin = (root / "scripts/sera_labo_round_skin.gd").read_text(encoding="utf-8")
card = (root / "ui/labo/LaboEquipmentCard.tscn").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert "CRAFT_CATALOG_SLOTS: int = 20" in fac
assert '"LockedCraftSlot_%02d"' in fac and '"—  LOCKED SLOT  —"' in fac
assert "LABO_CRAFT_CARD_HEIGHT: float = 160.0" in fac
assert "custom_minimum_size = Vector2(96, 96)" in card
assert '"font_size", 17 if key.begins_with("LockedCraftSlot_") else 20)' in fac
assert 'terminal_code.text = "MATERIAL"' in fac
assert 'tier_rail.color = Color("#79b6c2")' in fac
assert 'marker.color = Color("#79b6c2")' in grid
assert 'virtual_slots = (999 if mode == "equipment"' in grid
assert 'MAX_POOL_CARDS: int = 32' in grid
assert 'effects.position = Vector2(16.0, 101.0)' in grid
assert 'SelectedTabMark' in fac and 'Color("#74e3ed")' in fac
assert 'LaboSkin.panel_style()' in fac and 'static func panel_style()' in skin
assert 'fill.lerp(Color(' in skin, "cached card gradient must remain active"
assert '素材を精製し、より高品質な資材へ変換します。' in fac
assert 'py tools/v540_labo_visual_slots_self_check.py' in manifest
assert 'gd tools/v540_labo_visual_slots_runtime_check.gd' in manifest
print("SERA_V540_LABO_VISUAL_SLOTS_STATIC_PASS")
