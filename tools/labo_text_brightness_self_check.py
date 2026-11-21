#!/usr/bin/env python3
"""LAB: subtly muted light typography retains the original readable hierarchy."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
skin = (root / "scripts/sera_labo_round_skin.gd").read_text(encoding="utf-8")
facility = (root / "scripts/base_facility_system.gd").read_text(encoding="utf-8")
warehouse = (root / "scripts/sera_warehouse_grid.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")

# Approved palette for this small brightness-only adjustment. No font family,
# size, layout, material/state logic, or fx color change is authorized.
expected = {
    "button_normal": "#e2edf3",
    "button_disabled": "#bdceda",
    "button_interactive": "#edf7fa",
    "label": "#dcebf0",
    "input": "#e6f0f5",
    "modal_title": "#e4edf0",
    "nav_pressed": "#dceff3",
    "nav_hover": "#e2f0f5",
    "craft_title": "#eaf4f5",
    "material_title": "#eaf3f5",
    "warehouse_title": "#dde8ea",
    "warehouse_effects": "#b2ced3",
    "warehouse_breakdown": "#e0ebf1",
}
assert f'theme.set_color("font_color", "Button", Color("{expected["button_normal"]}"))' in skin
assert f'theme.set_color("font_disabled_color", "Button", Color("{expected["button_disabled"]}"))' in skin
for state in ("font_pressed_color", "font_hover_color", "font_hover_pressed_color"):
    assert f'theme.set_color("{state}", "Button", Color("{expected["button_interactive"]}"))' in skin
assert f'theme.set_color("font_color", "Label", Color("{expected["label"]}"))' in skin
assert f'theme.set_color("font_color", "LineEdit", Color("{expected["input"]}"))' in skin

for fragment in (
    f'modal_title.add_theme_color_override("font_color", Color("{expected["modal_title"]}"))',
    f'button.add_theme_color_override("font_pressed_color", Color("{expected["nav_pressed"]}"))',
    f'button.add_theme_color_override("font_hover_color", Color("{expected["nav_hover"]}"))',
    f'Color("{expected["material_title"]}")',
    f'Color("{expected["craft_title"]}")',
    f'breakdown.add_theme_color_override("font_color", Color("{expected["warehouse_breakdown"]}"))',
):
    assert fragment in facility, fragment
for fragment in (
    f'title.add_theme_color_override("font_color", Color("{expected["warehouse_title"]}"))',
    f'effects.add_theme_color_override("font_color", Color("{expected["warehouse_effects"]}"))',
):
    assert fragment in warehouse, fragment

def luminance(hex_color):
    rgb = [int(hex_color[i:i+2], 16) / 255 for i in (1, 3, 5)]
    return sum(weight * (v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055)**2.4)
               for weight, v in zip((0.2126, 0.7152, 0.0722), rgb))

assert luminance(expected["button_normal"]) > luminance(expected["button_disabled"])
assert luminance(expected["craft_title"]) > luminance("#8da9b5")  # locked slots stay muted
assert luminance(expected["warehouse_title"]) > luminance(expected["warehouse_effects"])
for key in ("button_normal", "button_interactive", "label", "modal_title",
            "craft_title", "material_title", "warehouse_title"):
    # Keep subtle dimming, not low-contrast body text.
    assert 0.70 < luminance(expected[key]) < 0.95, key
assert 'py tools/labo_text_brightness_self_check.py' in manifest
print("SERA_LABO_TEXT_BRIGHTNESS_STATIC_PASS")
