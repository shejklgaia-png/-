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

# Angular Noto Sans JP variable titles and stats replace rounded M PLUS faces.
# Both roles share one previously bundled font: no network or per-item loads.
for required in (
    'const JP_TITLE_FONT_PATH: String = JP_FONT_PATH',
    'const JP_STATS_FONT_PATH: String = JP_FONT_PATH',
    '_jp_title_source = _jp_face()',
    '_jp_stats_source = _jp_face()',
    '_title_font = _variation_from_face(_title_face(), 850)',
    '_equipment_font = _variation_from_face(_title_face(), 750)',
    '_stats_font = _variation_from_face(_stats_face(), 550)',
    '_title_font.spacing_glyph = 1',
    '_equipment_font.spacing_glyph = 1',
    '_control_font.spacing_glyph = 1',
    '_tracked_display.base_font = display_font()',
    '_tracked_data.base_font = data_font()',
    'theme.default_font = ui_font()',
):
    assert required in skin, required
assert 'JP_TITLE_FONT_PATH: String = "res://assets/fonts/MPLUS2' not in skin
assert 'JP_STATS_FONT_PATH: String = "res://assets/fonts/MPLUS1Code' not in skin
assert 'Roles: TITLE/EQUIPMENT/STATS=Noto Sans JP' in diag

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

# All shipped faces and license files remain in the repository. No new assets.
for filename in ("NotoSansJP-VF.woff2", "IBMPlexSansJP-Medium.woff2",
                 "IBMPlexSansJP-Bold.woff2", "Rajdhani-Bold.woff2",
                 "IBMPlexMono-Medium.woff2"):
    raw = (root / "assets/fonts" / filename).read_bytes()
    assert raw[:4] == b"wOF2" and len(raw) > 1000, filename
assert "SIL OPEN FONT LICENSE" in (
    root / "assets/fonts/OFL-NotoSansJP.txt").read_text("utf-8").upper()
assert "py tools/sera_sharp_cyber_fonts_self_check.py" in manifest
print("SERA_SHARP_CYBER_FONTS_STATIC_PASS")
