#!/usr/bin/env python3
"""v521: full-card tapping is a visual/input contract, not a label-sized button."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
ui = (root / "scripts/base_facility_system.gd").read_text(encoding="utf-8")
slot = (root / "scripts/sera_chamfer_slot.gd").read_text(encoding="utf-8")
ci = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert "func _new_slot(" in ui and "if action.is_valid():" in ui
assert "choose.name = action_name" in ui
assert "choose.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)" in ui
assert 'choose.mouse_filter = Control.MOUSE_FILTER_STOP' in ui
assert 'choose.add_theme_stylebox_override("normal", StyleBoxEmpty.new())' in ui
assert 'choose.tooltip_text = title' in ui
assert 'card.add_child(choose)' in ui, "full-card button must be a direct card child"
assert 'content.add_child(choose)' not in ui, "no name-only clickable region"
assert 'image.mouse_filter = Control.MOUSE_FILTER_IGNORE' in ui
assert 'heading.mouse_filter = Control.MOUSE_FILTER_IGNORE' in ui
assert 'quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE' in ui
assert "func _draw(" in slot and "_border_points" in slot, "keep chamfered frame"
for marker in ('"Choose_" + id', '"Open_" + str(family)', '"ShowOwned_" + id'):
    assert marker in ui, f"existing card action must remain callable: {marker}"
assert "gd tools/v521_full_card_touch_runtime_check.gd" in ci
print("SERA_V521_FULL_CARD_TOUCH_STATIC_PASS")
