#!/usr/bin/env python3
"""SERA: two Japanese-capable families, four installed OFL TTF faces."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
assets=root/"assets/fonts"
skin=(root/"scripts/sera_labo_round_skin.gd").read_text("utf-8")
ui=(root/"scripts/base_facility_system.gd").read_text("utf-8")
wh=(root/"scripts/sera_warehouse_grid.gd").read_text("utf-8")
diag=(root/"scripts/sera_font_diagnostics.gd").read_text("utf-8")
preset=(root/"export_presets.cfg").read_text("utf-8")
ci=(root/"tools/sera_ci_manifest.txt").read_text("utf-8")
for filename in (
    "UDEVGothic-Regular.ttf", "UDEVGothic-Bold.ttf",
    "MoralerspaceNeon-Regular.ttf", "MoralerspaceNeon-Bold.ttf"):
    data=(assets/filename).read_bytes()
    assert data[:4] in (b"\x00\x01\x00\x00", b"OTTO"), filename
    assert len(data)>50_000, filename
    assert filename in skin, filename
for filename in ("OFL-UDEVGothic.txt","OFL-Moralerspace.txt"):
    text=(assets/filename).read_text("utf-8")
    assert "SIL OPEN FONT LICENSE" in text.upper(), filename
for statement in (
    "_title_font = _variation_from_face(_title_face())",
    "_equipment_font = _variation_from_face(_title_face())",
    "_ui_font = _variation_from_face(_ui_face())",
    "_control_font = _variation_from_face(_control_face())",
    "_stats_font = _variation_from_face(_stats_face())",
    "static func equipment_font() -> FontVariation:",
    "_load_bundled_font(JP_UI_FONT_PATH, 0x88C5)",
    "_jp_title_source = _load_bundled_font(JP_TITLE_FONT_PATH, 0x88C5)",
    "_load_bundled_font(JP_CONTROL_FONT_PATH, 0x88C5)",
    "_jp_stats_source = _load_bundled_font(JP_STATS_FONT_PATH, 0x65E5)",
):
    assert statement in skin, statement
assert 'LaboSkin.equipment_font()))' in ui
assert 'LaboSkin.equipment_font()' in wh
assert 'LaboSkin.stats_font()' in wh and 'LaboSkin.stats_font()' in ui
assert 'LaboSkin.control_font()' in ui and 'LaboSkin.ui_font()' in ui
assert 'SERA FONT DIAG v548 / MIXED FONTS' in diag
assert 'JP EQUIPMENT' in diag
assert '"Aa 0123456789  UNIT / H01  SYSTEM ONLINE"' in ui
assert 'assets/fonts/*.ttf' in preset
assert 'MAX_POOL_CARDS: int = 32' in wh
assert 'virtual_slots = (999 if mode == "equipment"' in wh
assert 'CRAFT_CATALOG_SLOTS: int = 20' in ui
assert 'PrototypeBasePreview' not in ui
assert "py tools/v548_lab_font_mix_self_check.py" in ci
assert "gd tools/v548_lab_font_mix_runtime_check.gd" in ci
print("SERA_V548_LAB_FONT_MIX_STATIC_PASS")
