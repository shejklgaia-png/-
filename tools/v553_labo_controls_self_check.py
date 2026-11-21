#!/usr/bin/env python3
"""LABO: confirmation layout, font-free markings and 1..99 selectors."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
base = (root / "scripts/base_facility_system.gd").read_text(encoding="utf-8")
warehouse = (root / "scripts/sera_warehouse_grid.gd").read_text(encoding="utf-8")
marks = (root / "scripts/sera_mark_icon.gd").read_text(encoding="utf-8")
materials = (root / "scripts/sera_base_materials.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert "const MAX_BATCHES: int = 99" in materials
assert "batches > MAX_BATCHES" in materials
assert "var amount := SpinBox.new()" not in base
for token in ("ConversionStepper_", "ConversionMinus_", "ConversionCountFrame_",
              "ConversionCount_", "ConversionPlus_", 'amount_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER',
              'amount_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER',
              'increment.disabled = conversion_batches >= BaseMaterials.MAX_BATCHES',
              'decrement.disabled = conversion_batches <= 1'):
    assert token in base, token
for token in ('LaboConfirmCraftCard', 'LaboConfirmItemIcon',
              'LaboConfirmItemStats', 'LaboConfirmSaveNotice',
              '_craft_selected_prototype, selected_prototype'):
    assert token in base, token
assert 'func _request_confirmation(' in base
assert 'func _dismiss_confirmation()' in base
assert 'func _accept_confirmation()' in base
for token in ('_add_labo_mark_icon(junk_button, "junk")',
              '_add_labo_mark_icon(favorite, "favorite")',
              '_add_labo_mark_icon(junk, "junk")',
              'FavoriteMarkIcon', 'JunkMarkIcon'):
    assert token in base + warehouse, token
assert 'title.text = str(entry.get("name", ""))' in warehouse
assert 'title.text = mark +' not in warehouse
assert 'draw_colored_polygon(points, tint)' in marks
assert 'draw_rect(' in marks
assert 'py tools/v553_labo_controls_self_check.py' in manifest
assert 'gd tools/v553_labo_controls_runtime_check.gd' in manifest
print("SERA_V553_LABO_CONTROLS_STATIC_PASS")
