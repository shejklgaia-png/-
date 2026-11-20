#!/usr/bin/env python3
"""SERA v541: no duplicate equipment details in the LABO manufacture catalog."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
ui = (root / "scripts/base_facility_system.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
start = ui.index("func _show_prototype_catalog() -> void:")
end = ui.index("func _select_craft_slot(", start)
catalog = ui[start:end]
for obsolete in ("PrototypeBasePreview", "PrototypeBaseStats",
                 "PrototypeBaseArt", "BASE SPECIFICATION /", "var first_id:"):
    assert obsolete not in catalog, obsolete
assert 'var grid := _new_grid("PrototypeGrid", 1)' in catalog
assert 'LaboStats.baseline(id).replace("\\n", " / ")' in catalog
assert "CRAFT_CATALOG_SLOTS + 1" in catalog
assert '"LockedCraftSlot_%02d"' in catalog
assert 'py tools/v541_craft_detail_removed_self_check.py' in manifest
assert 'gd tools/v541_craft_detail_removed_runtime_check.gd' in manifest
print("SERA_V541_CRAFT_DETAIL_REMOVED_STATIC_PASS")
