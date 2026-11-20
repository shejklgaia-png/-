#!/usr/bin/env python3
"""v517: user-visible base shortcuts, clean labels and manual sample materials."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
def source(p): return (root / p).read_text(encoding="utf-8")
hub = source("scripts/base_exploration.gd")
facility = source("scripts/base_facility_system.gd")
save = source("scripts/sera_save.gd")
nexus = source("scripts/command_nexus.gd")
manifest = source("tools/sera_ci_manifest.txt")
assert 'BaseQuickActions' not in hub, "obsolete bottom bar"
assert '建物をタップ' in hub
assert 'func _create_trial_profile(' in facility
assert 'func claim_trial_materials(' in save
assert 'trial_materials_claimed' in save
assert 'func _claim_trial_materials(' in facility
assert 'IconAtlas.material_icon(' in facility and 'IconAtlas.equipment_icon(' in facility
assert '試作装備の製作' in facility
assert 'func _create_hud(' in hub
assert 'label.text = PrototypeCatalog.display_instance(' in nexus
assert '  ›' not in facility and '  ▸' not in facility
assert '"< %s >"' not in nexus
assert "gd tools/v517_base_accessibility_runtime_check.gd" in manifest
print("SERA_V517_UI_STATIC_PASS")
