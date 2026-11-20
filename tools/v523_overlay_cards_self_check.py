#!/usr/bin/env python3
"""v523: Android v522 shows no cards: render items in direct modal overlay."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
ui = (root/"scripts/base_facility_system.gd").read_text(encoding="utf-8")
ci = (root/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert 'var item_layer: Control' in ui
assert 'item_layer.name = "FacilityItemLayer"' in ui
assert 'body.add_child(item_layer)' in ui
assert 'item_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE' in ui
assert 'item_layer.add_child(grid)' in ui, "grid must NOT be inside the blank Android actions parent"
assert 'modal_actions.add_child(grid)' not in ui
assert 'func _position_item_grid(' not in ui
assert 'func _clear_actions() -> void:' in ui and 'item_layer.get_children()' in ui
assert 'item_layer.size_flags_horizontal = Control.SIZE_EXPAND_FILL' in ui
assert "gd tools/v523_overlay_cards_runtime_check.gd" in ci
print("SERA_V523_DIRECT_OVERLAY_CARDS_STATIC_PASS")
