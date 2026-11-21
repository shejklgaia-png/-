#!/usr/bin/env python3
"""Cyber typography: squared Japanese labels and technical combat/navigation type."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
skin = (root / "scripts/sera_labo_round_skin.gd").read_text(encoding="utf-8")
combat = (root / "scripts/main.gd").read_text(encoding="utf-8")
meters = (root / "scripts/sera_clean_training_hud.gd").read_text(encoding="utf-8")
touch = (root / "scripts/touch_overlay.gd").read_text(encoding="utf-8")
nexus = (root / "scripts/command_nexus.gd").read_text(encoding="utf-8")
version = (root / "scripts/version_indicator.gd").read_text(encoding="utf-8")
diag = (root / "scripts/sera_font_diagnostics.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")

# Role map: sharp UDEV for Japanese text and controls, Moralerspace
# Neon for stat tables, labels, engineering values and technical displays.
for required in (
    'const JP_FONT_PATH: String = "res://assets/fonts/UDEVGothic-Regular.ttf"',
    'const JP_TITLE_FONT_PATH: String = "res://assets/fonts/UDEVGothic-Bold.ttf"',
    'const JP_STATS_FONT_PATH: String = "res://assets/fonts/MoralerspaceNeon-Regular.ttf"',
    'const NAV_FONT_PATH: String = "res://assets/fonts/MoralerspaceNeon-Bold.ttf"',
    'const JP_UI_FONT_PATH: String = JP_FONT_PATH',
    'const JP_CONTROL_FONT_PATH: String = JP_TITLE_FONT_PATH',
    'const DATA_FONT_PATH: String = JP_STATS_FONT_PATH',
    '_jp_title_source = _load_bundled_font(JP_TITLE_FONT_PATH, 0x88C5)',
    '_jp_stats_source = _load_bundled_font(JP_STATS_FONT_PATH, 0x65E5)',
    '_title_font = _variation_from_face(_title_face())',
    '_equipment_font = _variation_from_face(_title_face())',
    '_stats_font = _variation_from_face(_stats_face())',
    '_title_font.spacing_glyph = 1',
    '_equipment_font.spacing_glyph = 1',
    '_control_font.spacing_glyph = 1',
    'theme.default_font = ui_font()',
):
    assert required in skin, required
assert 'NotoSansJP-VF.woff2' not in skin
assert 'Roles: TITLE/EQUIPMENT/CONTROL=UDEV Gothic' in diag

# Non-menu gameplay labels also receive actual bundled font objects.
for required in (
    'const LaboTypography = preload("res://scripts/sera_labo_round_skin.gd")',
    'nexus_button.add_theme_font_override("font", LaboTypography.tracked_display_font())',
    'damage_label.add_theme_font_override("font", LaboTypography.tracked_data_font())',
    'history_label.add_theme_font_override("font", LaboTypography.tracked_data_font())',
    'clean_training_hud.theme = LaboTypography.common_theme()',
    'touch_ui.theme = LaboTypography.common_theme()',
):
    assert required in combat, required
assert 'func _font_for_text(value: String) -> Font:' in meters
assert 'LaboTypography.tracked_display_font()' in meters
assert 'LaboTypography.tracked_data_font()' in meters
assert 'LaboTypography.equipment_font()' in meters
assert 'LaboTypography.tracked_display_font()' in touch
assert 'logo.font = LaboSkin.display_font()' in nexus
assert 'name.font = LaboSkin.display_font()' in nexus
assert 'version_label.add_theme_font_override("font", LaboTypography.tracked_data_font())' in version
assert 'var font: Font = get_theme_default_font()' not in meters
assert 'var font: Font = get_theme_default_font()' not in touch

# Both actual Japanese-capable families must be vendored and licensed.
for filename in ("UDEVGothic-Regular.ttf", "UDEVGothic-Bold.ttf",
                 "MoralerspaceNeon-Regular.ttf", "MoralerspaceNeon-Bold.ttf"):
    raw = (root / "assets/fonts" / filename).read_bytes()
    assert raw[:4] in (bytes([0, 1, 0, 0]), b"OTTO"), filename
    assert len(raw) > 50_000, filename
for license_name in ("OFL-UDEVGothic.txt", "OFL-Moralerspace.txt"):
    text = (root / "assets/fonts" / license_name).read_text("utf-8")
    assert "SIL OPEN FONT LICENSE" in text.upper(), license_name
assert "py tools/sera_sharp_cyber_fonts_self_check.py" in manifest
print("SERA_SHARP_CYBER_FONTS_STATIC_PASS")
