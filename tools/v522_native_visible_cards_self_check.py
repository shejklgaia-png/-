#!/usr/bin/env python3
"""v522: Android v521 screenshots were blank despite all old GUI-tree tests passing.
The content must be standard Godot Button controls in HBox rows, not custom cards.
"""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
ui = (root/"scripts/base_facility_system.gd").read_text(encoding="utf-8")
skin = (root/"scripts/sera_chamfer_skin.gd").read_text(encoding="utf-8")
manifest = (root/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert 'const ChamferSkin = preload("res://scripts/sera_chamfer_skin.gd")' in ui
assert 'var card := Button.new()' in ui, "use native Button, not scripted PanelContainer"
assert 'card.icon = icon' in ui and 'card.text = title + "\\n" + info' in ui
assert 'row = HBoxContainer.new()' in ui and 'var grid := VBoxContainer.new()' in ui
assert 'GridContainer.new()' not in ui
assert 'ChamferSlot.new()' not in ui
assert 'card.add_theme_stylebox_override("normal", ChamferSkin.style(' in ui
assert 'card.pressed.connect(action)' in ui
assert '"FacilityActionsArea"' in ui
assert 'StyleBoxTexture.new()' in skin and 'ImageTexture.create_from_image(' in skin
assert 'set_texture_margin' in skin and 'Image.FORMAT_RGBA8' in skin
assert "gd tools/v522_native_cards_runtime_check.gd" in manifest
print("SERA_V522_NATIVE_VISIBLE_CARDS_STATIC_PASS")
