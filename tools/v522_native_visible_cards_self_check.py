#!/usr/bin/env python3
"""v522: Android v521 screenshots were blank despite all old GUI-tree tests passing.
The content must be standard Godot Button controls in HBox rows, not custom cards.
"""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
ui = (root/"scripts/base_facility_system.gd").read_text(encoding="utf-8")
skin = (root/"scripts/sera_labo_round_skin.gd").read_text(encoding="utf-8")
manifest = (root/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert 'const LaboSkin = preload("res://scripts/sera_labo_round_skin.gd")' in ui
assert 'var card := Button.new()' in ui, "use native Button, not scripted PanelContainer"
assert 'card.icon = icon' in ui and 'card.text = title + "\\n" + info' in ui
assert 'row = HBoxContainer.new()' in ui and 'var grid := VBoxContainer.new()' in ui
assert 'GridContainer.new()' not in ui
assert 'ChamferSlot.new()' not in ui
assert 'card.add_theme_stylebox_override("normal", LaboSkin.style(' in ui
assert 'card.pressed.connect(action)' in ui
assert '"FacilityActionsArea"' in ui
assert 'StyleBoxFlat.new()' in skin and 'set_corner_radius_all(' in skin
assert 'bg_color' in skin and 'border_color' in skin
assert "gd tools/v522_native_cards_runtime_check.gd" in manifest
assert "xvfb-run" in (root/".github/workflows/sera-model-policy.yml").read_text(encoding="utf-8")
assert "v522_visible_card_pixels_runtime_check.gd" in (root/".github/workflows/sera-model-policy.yml").read_text(encoding="utf-8")
print("SERA_V522_NATIVE_VISIBLE_CARDS_STATIC_PASS")
