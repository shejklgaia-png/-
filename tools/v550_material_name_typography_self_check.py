#!/usr/bin/env python3
"""SERA v550: medium-weight material names use one responsive size everywhere."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
ui = (root / "scripts/base_facility_system.gd").read_text(encoding="utf-8")
skin = (root / "scripts/sera_labo_round_skin.gd").read_text(encoding="utf-8")
ci = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert "IBMPlexSansJP-Medium.woff2" in skin
for token in (
    "var _uniform_material_name_size: int = 16",
    "func _fit_material_titles(grid: VBoxContainer) -> void:",
    "for material_id in BaseMaterials.all_ids():",
    "var minimum_width: float = INF",
    "minimum_width = minf(minimum_width, available)",
    "var font: Font = LaboSkin.ui_font()",
    "for label in titles:",
    "label.add_theme_font_size_override(\"font_size\", chosen)",
    "_uniform_material_name_size = chosen",
    "grid.resized.connect(_fit_material_titles.bind(grid), CONNECT_DEFERRED)",
    'call_deferred("_fit_material_titles", grid)',
    "LaboSkin.ui_font() if material_choice else",
    'recipe_title.add_theme_font_override("font", LaboSkin.ui_font())',
    'recipe_info.add_theme_font_override("font", LaboSkin.ui_font())',
    'recipe_title.autowrap_mode = TextServer.AUTOWRAP_OFF',
    'recipe_info.autowrap_mode = TextServer.AUTOWRAP_OFF',
):
    assert token in ui, token
assert "card.resized.connect(_fit_material_title.bind(card))" not in ui
assert "_fit_material_title(card: Button)" not in ui
assert 'py tools/v550_material_name_typography_self_check.py' in ci
assert 'gd tools/v549_refinery_names_warehouse_glyphs_runtime_check.gd' in ci
print("SERA_V550_MATERIAL_TYPOGRAPHY_STATIC_PASS")
