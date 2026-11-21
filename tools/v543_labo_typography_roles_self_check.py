#!/usr/bin/env python3
"""SERA v543: role-based typography, three compatible families, no font downloads."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
skin = (root / "scripts/sera_labo_round_skin.gd").read_text(encoding="utf-8")
ui = (root / "scripts/base_facility_system.gd").read_text(encoding="utf-8")
store = (root / "scripts/sera_warehouse_grid.gd").read_text(encoding="utf-8")
ci = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")

for name in ("ui_font", "title_font", "control_font", "stats_font"):
    assert f"static func {name}() -> FontVariation:" in skin, name
for name in ("display_font", "data_font"):
    assert f"static func {name}() -> FontFile:" in skin, name
for token in ("NotoSansJP-VF.woff2",
              "IBMPlexSansJP-Medium.woff2", "IBMPlexSansJP-Bold.woff2",
              "Rajdhani-Bold.woff2", "IBMPlexMono-Medium.woff2",
              "static func equipment_font()", "_variation_from_face(",
              "_title_face(), 850", "_stats_face(), 550"):
    assert token in skin, token

assert 'button.add_theme_font_override("font", LaboSkin.tracked_display_font())' in ui
assert 'modal_title.add_theme_font_override("font", LaboSkin.title_font())' in ui
assert 'button.add_theme_font_override("font", LaboSkin.control_font())' in ui
assert 'LaboSkin.tracked_display_font() if key.begins_with("LockedCraftSlot_")' in ui
assert 'LaboSkin.tracked_data_font() if key.begins_with("LockedCraftSlot_")' in ui
assert 'LaboSkin.stats_font()))' in ui
assert 'recipe_info.add_theme_font_override("font", LaboSkin.ui_font())' in ui
assert '"font_size", 17 if key.begins_with("LockedCraftSlot_") else 20)' in ui
assert 'title.add_theme_font_override("font", (' in store
assert 'effects.add_theme_font_override("font", LaboSkin.stats_font())' in store
assert 'empty.add_theme_font_override("font", LaboSkin.tracked_display_font())' in store
assert 'MAX_POOL_CARDS: int = 32' in store
assert 'virtual_slots = (999 if mode == "equipment"' in store
assert 'PrototypeBasePreview' not in ui
assert 'py tools/v543_labo_typography_roles_self_check.py' in ci
assert 'gd tools/v543_labo_typography_roles_runtime_check.gd' in ci
print("SERA_V543_LABO_TYPOGRAPHY_ROLES_STATIC_PASS")
