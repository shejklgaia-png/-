#!/usr/bin/env python3
"""v529 independently approved hanger, affix, and virtual warehouse contract."""
from pathlib import Path
p=Path(__file__).resolve().parents[1]
ui=(p/"scripts/base_facility_system.gd").read_text(encoding="utf-8")
store=(p/"scripts/sera_save.gd").read_text(encoding="utf-8")
grid=(p/"scripts/sera_warehouse_grid.gd").read_text(encoding="utf-8")
affixes=(p/"scripts/sera_craft_affixes.gd").read_text(encoding="utf-8")
manifest=(p/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert "const HANGER_LIMIT: int = 999" in store
assert 'Affixes.roll_five()' in store
assert '"affixes"' in store
assert 'var warehouse_slot: String = "head"' in ui
assert 'const WarehouseGrid = preload("res://scripts/sera_warehouse_grid.gd")' in ui
assert 'grid.configure(entries, 2, "equipment")' in ui
assert 'grid.configure(entries, 3, "materials")' in ui
assert 'owned_count' not in ui.split("func _show_prototype_catalog() -> void:",1)[1].split("func _select_prototype(",1)[0]
assert 'signal entry_pressed' in grid
assert 'get_v_scroll_bar().value_changed.connect' in grid
assert 'var card := Button.new()' in grid
assert 'StyleBoxTexture.new()' in grid
assert 'func _refresh_visible(' in grid
assert 'const EFFECT_IDS' in affixes and 'static func roll_five(' in affixes
assert 'py tools/v529_warehouse_affixes_self_check.py' in manifest
assert 'gd tools/v529_warehouse_affixes_runtime_check.gd' in manifest
print("SERA_V529_WAREHOUSE_AFFIXES_STATIC_PASS")
