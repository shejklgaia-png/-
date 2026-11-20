#!/usr/bin/env python3
"""Approved LABO v528: one live 3D hero, low-cost Crate, rounded blue-grey native UI."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
ui = (root/"scripts/base_facility_system.gd").read_text(encoding="utf-8")
stage = (root/"scripts/labo_hero_stage.gd").read_text(encoding="utf-8")
skin = (root/"scripts/sera_labo_round_skin.gd").read_text(encoding="utf-8")
manifest = (root/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
scene = (root/"scenes/labo_hero_stage.tscn").read_text(encoding="utf-8")
assert 'SubViewportContainer.new()' in ui and 'SubViewport.new()' in ui
assert 'func _set_labo_hero(' in ui and 'func _ensure_labo_hero(' in ui
assert 'labo_hero_stage.tscn' in ui and 'labo_hero_stage.gd' in scene
assert 'SubViewport.UPDATE_DISABLED' in ui
assert 'SubViewport.UPDATE_WHEN_VISIBLE' in ui
assert 'hero_stage.set_process(' in ui
assert 'get_visible_rect().size.y * 0.30' in ui, "30% of visible screen is always LABO 3D"
for section in ('"LABO"', '"SMELTER"', '"RECYCLER"', '"STORAGE"'):
    assert section in ui
assert 'const LaboSkin = preload(' in ui and 'StyleBoxFlat' in skin
assert 'set_corner_radius_all(' in skin
assert 'LaboSkin.style("card")' in ui
assert 'card.mouse_filter = Control.MOUSE_FILTER_STOP' in ui
assert 'card.text = title + "\\n" + info' in ui
assert 'ScrollContainer.new()' in ui, "native scroll is required in LABO", "keep Android-tested native layout"
assert 'func _process(delta: float)' in stage and 'move_toward(' in stage
assert '"Crate"' in stage and '"PrinterNozzle"' in stage
assert '"TerminalScreen"' in stage and '"PrintedPart"' in stage
assert 'NavigationAgent3D.new()' not in stage
assert 'labo_hero_stage.gd' not in (root/"models/manifest.json").read_text(encoding="utf-8")
assert 'py tools/labo_3d_hero_self_check.py' in manifest
assert 'gd tools/labo_3d_hero_runtime_check.gd' in manifest
print("SERA_LABO_3D_HERO_STATIC_PASS")
