#!/usr/bin/env python3
"""LABO direct craft landing + visible slot tabs + bounded centered icons."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
ui = (root / "scripts/base_facility_system.gd").read_text(encoding="utf-8")
ci = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert 'func open_facility(key: String) -> void:' in ui
assert 'if key == "LABO":' in ui and '_show_prototype_catalog()' in ui
assert '"OpenPrototypeCatalog"' not in ui
assert '"ClaimTrialMaterialsCatalog"' not in ui
assert '"ClaimTrialMaterials"' not in ui
assert '"WarehouseHangerTabs"' in ui
assert '"CraftSlotTabs"' in ui
assert '"WarehouseHangerTabs"' in ui
assert '"CraftSlotScroll"' not in ui and '"WarehouseHangerScroll"' not in ui
assert '"WarehouseHangerSelector"' not in ui
assert 'OptionButton.new()' not in ui
assert 'ButtonGroup.new()' in ui and 'Control.SIZE_EXPAND_FILL' in ui
assert 'func _slot_tab_caption(' in ui
assert 'MATERIAL_CARD_HEIGHT' in ui
assert 'MATERIAL_ICON_WIDTH' in ui
assert 'card.icon = null' in ui and 'art.clip_contents = true' in ui
assert 'material_icon_sized(' in ui
assert 'icon_max_width' not in ui
assert 'CanvasItem.TEXTURE_FILTER_NEAREST' in ui and 'LaboSkin.card_style(' in ui
assert 'py tools/v532_labo_entry_icons_self_check.py' in ci
assert 'gd tools/v532_labo_entry_icons_runtime_check.gd' in ci
print("SERA_V532_LABO_ENTRY_ICONS_STATIC_PASS")
