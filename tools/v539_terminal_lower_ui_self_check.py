#!/usr/bin/env python3
"""SERA v539 compact industrial LABO lower-panel design contract."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
ui=(root/"scripts/base_facility_system.gd").read_text(encoding="utf-8")
skin=(root/"scripts/sera_labo_round_skin.gd").read_text(encoding="utf-8")
warehouse=(root/"scripts/sera_warehouse_grid.gd").read_text(encoding="utf-8")
ci=(root/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert 'func _show_inventory(section: String = "equipment")' in ui
assert 'modal_body.visible = false' in ui
assert 'func _style_terminal_segment(' in ui
assert 'static func terminal_segment_style(' in skin
assert 'static var _segment_cache:' in skin
assert 'func _add_terminal_notice(' in ui
assert 'card.get_node("CardContent/Row/ItemArt")' in ui
assert 'UnitSerial' in ui and 'TierRail' in ui
assert 'PrototypeBasePreview' in ui and 'PrototypeBaseArt' in ui
assert 'WarehouseCategoryTabs' in ui and 'CraftSlotTabs' in ui and 'WarehouseHangerTabs' in ui
assert 'ConvertInputIcon_' in ui and 'ConvertOutputIcon_' in ui
assert 'EmptySlotLabel' in warehouse and 'ItemEffects' in warehouse
assert 'MAX_POOL_CARDS: int = 32' in warehouse
assert 'py tools/v539_terminal_lower_ui_self_check.py' in ci
assert 'gd tools/v539_terminal_lower_ui_runtime_check.gd' in ci
print("SERA_V539_TERMINAL_LOWER_STATIC_PASS")
