#!/usr/bin/env python3
"""SERA v549: compact refinery icons, single-line full labels, Japanese formula glyphs."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
fac=(root/"scripts/base_facility_system.gd").read_text(encoding="utf-8")
skin=(root/"scripts/sera_labo_round_skin.gd").read_text(encoding="utf-8")
manifest=(root/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
for token in (
    "func _fit_material_titles(grid: VBoxContainer) -> void:",
    'grid.resized.connect(_fit_material_titles.bind(grid), CONNECT_DEFERRED)',
    'call_deferred("_fit_material_titles", grid)',
    'art_dock.name = "MaterialArtOffset"',
    'art_dock.add_theme_constant_override("margin_top", 7)',
    'material_padding.add_theme_constant_override("margin_left", 12)',
    'material_row.add_theme_constant_override("separation", 12)',
    "art.reparent(art_dock, false)",
    "title_label.autowrap_mode = TextServer.AUTOWRAP_OFF",
    "title_label.max_lines_visible = 2",
    "title_label.clip_text = true",
    'get_string_size(',
    'return 46.0 if width >= 590.0 else 40.0 if width >= 460.0 else 30.0',
    'breakdown.add_theme_font_override("font", LaboSkin.stats_font())',
):
    assert token in fac, token
assert 'breakdown.add_theme_font_override("font", LaboSkin.data_font())' not in fac
assert 'static func stats_font() -> FontVariation:' in skin
assert 'MPLUS1Code-VF.woff2' in skin
assert 'py tools/v549_refinery_names_warehouse_glyphs_self_check.py' in manifest
assert 'gd tools/v549_refinery_names_warehouse_glyphs_runtime_check.gd' in manifest
print("SERA_V549_REFINERY_GLYPHS_STATIC_PASS")
