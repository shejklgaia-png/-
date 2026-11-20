#!/usr/bin/env python3
"""v524: make cards ordinary siblings of visible tabs, never use manual coordinates.
Also prevent 2+ selected section tabs or warehouse category tabs."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
ui=(root/"scripts/base_facility_system.gd").read_text(encoding="utf-8")
manifest=(root/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert 'item_layer.name = "FacilityItemLayer"' in ui
assert 'body.add_child(item_layer)' in ui
assert 'modal.add_child(item_layer)' not in ui
assert 'item_layer.size_flags_horizontal = Control.SIZE_EXPAND_FILL' in ui
assert 'actions_area.size_flags_vertical = Control.SIZE_SHRINK_BEGIN' in ui
assert 'modal_actions.size_flags_vertical = Control.SIZE_SHRINK_BEGIN' in ui
assert 'body.add_child(expand_spacer)' in ui
assert 'item_layer.add_child(grid)' in ui
assert 'var section_group := ButtonGroup.new()' in ui
assert 'button.button_group = section_group' in ui
assert 'var warehouse_group := ButtonGroup.new()' in ui
assert 'button.button_group = warehouse_group' in ui
assert 'func _position_item_grid(' not in ui
assert 'grid.position = Vector2(' not in ui
assert "gd tools/v524_layout_tabs_runtime_check.gd" in manifest
print("SERA_V524_LAYOUT_TABS_STATIC_PASS")
