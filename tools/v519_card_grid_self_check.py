#!/usr/bin/env python3
"""v519: no redundant bottom bar, visible chamfered grids for empty entries."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
def get(p): return (root/p).read_text(encoding="utf-8")
hub=get("scripts/base_exploration.gd")
ui=get("scripts/base_facility_system.gd")
slot=get("scripts/sera_chamfer_slot.gd")
manifest=get("tools/sera_ci_manifest.txt")
assert "BaseQuickActions" not in hub
assert "ScrollContainer.new()" not in ui
assert '"FacilityActionsArea"' in ui
assert 'const ChamferSlot = preload("res://scripts/sera_chamfer_slot.gd")' in ui
assert 'GridContainer.new()' in ui
for name in ('PrototypeGrid','MaterialFamilyGrid','WarehouseMaterials','WarehouseEquipment'):
    assert '"'+name+'"' in ui, "Missing visible grid: "+name
assert 'func _show_warehouse_equipment(' in ui
assert 'func _draw(' in slot and 'PackedVector2Array' in slot
assert "gd tools/v519_card_grid_runtime_check.gd" in manifest
print("SERA_V519_CARD_GRID_STATIC_PASS")
