#!/usr/bin/env python3
"""LABO reference-style regression: fixed touch dimensions, readable fonts, cyan active state."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
skin = (root / "scripts/sera_labo_round_skin.gd").read_text(encoding="utf-8")
ui = (root / "scripts/base_facility_system.gd").read_text(encoding="utf-8")
scene = (root / "ui/labo/LaboSectionTab.tscn").read_text(encoding="utf-8")
assert 'style("hover_pressed")' in skin
assert 'theme.set_stylebox("hover_pressed", "Button"' in skin
assert 'theme.set_color("font_hover_pressed_color", "Button"' in skin
assert 'result.set_corner_radius_all(5)' in skin
assert 'theme.default_font = ui_font()' in skin
assert 'LaboSkin.title_font()' in ui and 'LaboSkin.data_font()' in ui
assert 'modal_body.add_theme_font_size_override("font_size", 19)' in ui
for token in ("LABO_NAV_HEIGHT: float = 64.0", "LABO_SLOT_HEIGHT: float = 58.0",
              "LABO_BACK_HEIGHT: float = 66.0", "LABO_CRAFT_CARD_HEIGHT: float = 108.0"):
    assert token in ui, token
assert 'text_overrun_behavior = 3' in scene
print("SERA_V536_LABO_REFERENCE_STYLE_PASS")
