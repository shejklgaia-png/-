#!/usr/bin/env python3
"""Portable IRIS equipment editing and actual game portrait contracts."""
from pathlib import Path
from html.parser import HTMLParser

ROOT = Path(__file__).resolve().parents[2]
def read(path):
    return (ROOT/path).read_text(encoding="utf-8")
html = read("tools/equipment_intake/dist/SERA_Equipment_Intake_IRIS.html")
ui = read("tools/equipment_intake/intake_ui.js")
preview = read("tools/equipment_intake/godot_preview.gd")
game = read("scripts/base_facility_system.gd")
icons = read("scripts/sera_item_icons.gd")
bg = read("scripts/sera_icon_background.gd")
guide = read("docs/SERA_EQUIPMENT_CROSS_CHAT_HANDOFF_ja.md")
for item in ["distXAxisTitle", "distYAxisTitle", "横軸 X", "縦軸 Y", "右ほど高い", "上ほど高い"]:
    assert item in html, item
for item in ['fillText("X → "', 'fillText("Y ↑ "', 'c.rotate(-Math.PI/2)', 'side=w*.68']:
    assert item in ui, item
for item in ["SERA_EQUIPMENT_CHAT_HANDOFF_V1", "https://github.com/shejklgaia-png/-",
             "source.repository_path", "special_effects", "render_preset_text"]:
    assert item in ui or item in guide, item
assert 'id="exportText"' in html
assert "new chat" not in html or "新規" in html
assert "from GitHub" not in html or "GitHub" in html
assert "rig_set:selected[slot]" in ui
assert "SERA_INTAKE_RENDER" in ui
for item in ["_reanchor_gesture()", "_on_preview_drag", "next_center", "last_center",
             "last_distance", "24.0", "background_mode", "IconBackdrop.texture"]:
    assert item in preview, item
assert "function reanchor()" in html
assert "pinch.d>24&&d>24" in html
assert "touch-action:none" in html
for item in ["#111e28", "#55798A", "GRID_DIVISIONS", "GRID_OPACITY", "make_image",
             "composite", "Image.INTERPOLATE_NEAREST"]:
    assert item in bg, item
assert "IconBackground.composite(source)" in icons
assert "_presented_equipment_cache" in icons
assert "EquipmentPreview.new()" in game
assert "confirmation_preview_host" in game
assert '_show_craft_rotatable_part' in game
assert '"mode": "icon"' in game
assert '"background_mode": "grid"' in game
assert "SubViewport.UPDATE_DISABLED" in game
assert "EquipmentPreview" in game
assert "NEXUS_pose" in preview
assert "ソース表示" in read("docs/SERA_HTML_ARTIFACT_DELIVERY_POLICY_ja.md") or "Raw" in read("docs/SERA_HTML_ARTIFACT_DELIVERY_POLICY_ja.md")
print("SERA_PORTABLE_EQUIPMENT_GRID_GESTURE_STATIC_OK")
