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
assert '"WarehouseHangerScroll"' in ui
assert '"WarehouseHangerSelector"' not in ui
assert 'OptionButton.new()' not in ui
assert 'ButtonGroup.new()' in ui and 'scroll.horizontal_scroll_mode' in ui
assert 'MATERIAL_CARD_HEIGHT' in ui
assert 'MATERIAL_ICON_WIDTH' in ui
assert 'card.expand_icon = true' in ui
assert 'card.icon_max_width = ' in ui
assert 'card.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER' in ui
assert 'py tools/v532_labo_entry_icons_self_check.py' in ci
assert 'gd tools/v532_labo_entry_icons_runtime_check.gd' in ci
print("SERA_V532_LABO_ENTRY_ICONS_STATIC_PASS")
