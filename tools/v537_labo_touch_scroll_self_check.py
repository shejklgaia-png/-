#!/usr/bin/env python3
"""SERA LABO: touch drag must scroll without changing global battle input."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
ui = (root / "scripts/base_facility_system.gd").read_text(encoding="utf-8")
scroll = (root / "scripts/sera_labo_touch_scroll.gd").read_text(encoding="utf-8")
warehouse = (root / "scripts/sera_warehouse_grid.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")

assert 'pointing/emulate_mouse_from_touch=false' in project, "do not alter combat touch behavior"
assert "extends ScrollContainer" in scroll
for anchor in (
    "InputEventScreenTouch", "InputEventScreenDrag",
    "get_global_rect().has_point", "scroll_vertical",
    "func touch_drag_consumed(", "DRAG_DEADZONE",
):
    assert anchor in scroll, anchor
assert 'const LaboTouchScroll = preload("res://scripts/sera_labo_touch_scroll.gd")' in ui
assert 'actions_scroll = LaboTouchScroll.new()' in ui
assert 'var scroll := LaboTouchScroll.new()' in ui
assert 'PrototypeBasePreview' not in ui, "retired craft detail must stay removed"
assert 'var grid := _new_grid("PrototypeGrid", 1)' in ui, "craft cards must remain scrollable"
assert 'pressed.connect(_invoke_scroll_action.bind(' in ui, "drag must not trigger item action"
assert 'extends "res://scripts/sera_labo_touch_scroll.gd"' in warehouse
assert 'if touch_drag_consumed():' in warehouse
assert "set_touch_scroll_enabled" in scroll and "_set_labo_scroll_input_enabled" in ui
assert "py tools/v537_labo_touch_scroll_self_check.py" in manifest
assert "gd tools/v537_labo_touch_scroll_runtime_check.gd" in manifest
print("SERA_V537_LABO_TOUCH_SCROLL_STATIC_PASS")
