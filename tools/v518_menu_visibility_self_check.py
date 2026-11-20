#!/usr/bin/env python3
"""v518: users must discover and reach every LABO section on portrait screens."""
from pathlib import Path
p = Path(__file__).resolve().parents[1]
hub = (p / "scripts/base_exploration.gd").read_text(encoding="utf-8")
facility = (p / "scripts/base_facility_system.gd").read_text(encoding="utf-8")
manifest = (p / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert 'BaseQuickActions' not in hub
assert 'facility_system.call("_switch_section", target)' in hub
for marker in ("FacilitySectionTabs", "TabCraft", "TabMaterials", "TabWarehouse",
               "func _switch_section(", "func _sync_section_tabs("):
    assert marker in facility, "Missing persistent navigation: " + marker
assert '"FacilityActionsArea"' in facility and 'ScrollContainer.new()' not in facility
assert 'button.toggle_mode = true' in facility
runtime = (p / "tools/v518_menu_visibility_runtime_check.gd").read_text(encoding="utf-8")
assert 'InputEventScreenTouch.new()' in runtime
assert 'root.push_input(down, true)' in runtime
assert 'root.push_input(up, true)' in runtime
assert '.pressed.emit()' not in runtime, "v518 must exercise actual viewport GUI"
assert "gd tools/v518_menu_visibility_runtime_check.gd" in manifest
print("SERA_V518_MENU_VISIBILITY_STATIC_PASS")
