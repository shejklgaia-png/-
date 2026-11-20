#!/usr/bin/env python3
"""v521 intent: the ENTIRE card is the press target; updated for native v522 UI."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
ui = (root/"scripts/base_facility_system.gd").read_text(encoding="utf-8")
ci = (root/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert "func _new_slot(" in ui and "if action.is_valid():" in ui
assert 'LaboMaterialCardScene.instantiate()' in ui and 'LaboEquipmentCardScene.instantiate()' in ui
assert 'card.mouse_filter = Control.MOUSE_FILTER_STOP' in ui
assert 'card.pressed.connect(_invoke_scroll_action.bind(' in ui
assert 'action, parent.get_parent() as ScrollContainer' in ui
assert 'func _invoke_scroll_action(action: Callable, scroll: ScrollContainer) -> void:' in ui
assert 'bool(scroll.call("touch_drag_consumed"))' in ui, "dragged card must not execute press"
assert 'card.icon = null' in ui and 'art.texture = icon' in ui
assert 'card.text = title + "\\n" + info' in ui
assert 'card.add_theme_stylebox_override("normal", LaboSkin.card_style(' in ui
assert "GridContainer.new()" not in ui
assert 'card.add_child(choose)' not in ui, "no hidden overlaid child button"
for text in ('_select_prototype.bind(id)', '_select_conversion_family.bind(str(family))', 'grid.entry_pressed.connect(_on_warehouse_entry_pressed)'):
    assert text in ui, text
assert 'gd tools/v521_full_card_touch_runtime_check.gd' in ci
print("SERA_V521_FULL_CARD_TOUCH_STATIC_PASS")
