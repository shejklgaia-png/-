#!/usr/bin/env python3
"""v518: users must discover and reach every LABO section on portrait screens."""
from pathlib import Path
p = Path(__file__).resolve().parents[1]
hub = (p / "scripts/base_exploration.gd").read_text(encoding="utf-8")
facility = (p / "scripts/base_facility_system.gd").read_text(encoding="utf-8")
manifest = (p / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert 'BaseQuickActions' in hub
assert 'facility_system.call("_switch_section", target)' in hub
for marker in ("FacilitySectionTabs", "TabCraft", "TabMaterials", "TabWarehouse",
               "func _switch_section(", "func _sync_section_tabs("):
    assert marker in facility, "Missing persistent navigation: " + marker
assert 'actions_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED' in facility
assert 'button.toggle_mode = true' in facility
assert "gd tools/v518_menu_visibility_runtime_check.gd" in manifest
print("SERA_V518_MENU_VISIBILITY_STATIC_PASS")
