#!/usr/bin/env python3
"""LABO: keep zero-cost hidden diagnostics and accurate tab selection."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
ui = (root / "scripts/base_facility_system.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert 'diagnostic_button.visible = false' in ui
assert 'modal_title.gui_input.connect(_on_modal_title_input)' in ui
assert 'func _on_modal_title_input(' in ui
assert 'diag_header_taps' in ui and 'Time.get_ticks_msec()' in ui
assert 'diagnostic_readout.visible = false' in ui
assert 'if page in ["prototypes", "prototype_detail"]:' in ui
assert 'func _show_prototype_catalog(' in ui
# Existing native cards, deferred WebP icons, and 3-column visible layout stay.
assert 'body.add_child(item_layer)' in ui
assert 'var grid := VBoxContainer.new()' in ui
assert 'func _queue_card_icon(' in ui
assert 'LaboTouchScroll.new()' in ui, "native scroll is required in LABO"
assert 'py tools/labo_lightweight_ui_self_check.py' in manifest
assert 'gd tools/labo_lightweight_ui_runtime_check.gd' in manifest
print("SERA_LABO_LIGHTWEIGHT_UI_STATIC_PASS")
