#!/usr/bin/env python3
"""SERA v551: symmetrical material-card spacing, grey unavailable items,
two explicit lines of Japanese grade/family and five starter scraps."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
ui=(root/"scripts/base_facility_system.gd").read_text("utf-8")
materials=(root/"scripts/sera_base_materials.gd").read_text("utf-8")
save=(root/"scripts/sera_save.gd").read_text("utf-8")
ci=(root/"tools/sera_ci_manifest.txt").read_text("utf-8")
for token in (
    'const STARTER_SCRAP_COUNT: int = 5',
    'static func display_lines(material_id: String) -> String:',
    'static func starter_inventory() -> Dictionary:',
    'stock["scrap_low"] = STARTER_SCRAP_COUNT',
    'return str(grade[parts[1]]) + "\\n" + str(FAMILY_NAMES[parts[0]])',
):
    assert token in materials, token
assert '"materials": BaseMaterials.starter_inventory()' in save
assert 'data.get("materials", {})' in save and (
    'BaseMaterials.sanitize_inventory(' in save)
assert 'static func empty_inventory() -> Dictionary:' in materials
assert 'stock[material_id] = 0' in materials
for token in (
    'material_padding.add_theme_constant_override("margin_left", 12)',
    'material_row.add_theme_constant_override("separation", 12)',
    'title_label.max_lines_visible = 2',
    'BaseMaterials.display_lines(id)',
    'card.set_meta("out_of_stock", count == 0)',
    'card.modulate = Color(0.56, 0.56, 0.56, 1.0)',
    'bar.set_meta("out_of_stock", none_owned)',
    'if none_owned or bar.disabled:',
    'for one_line in label.text.split("\\n"):',
):
    assert token in ui, token
assert 'card.disabled = count == 0' not in ui
assert 'py tools/v551_refinery_spacing_starter_self_check.py' in ci
assert 'gd tools/v551_refinery_spacing_starter_runtime_check.gd' in ci
print("SERA_V551_REFINERY_SPACING_STARTER_STATIC_PASS")
