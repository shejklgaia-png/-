#!/usr/bin/env python3
"""Approved 19 real equipment variants, live stats source and no mock-up catalog."""
from pathlib import Path
from icon_studio.validate_all_icons import catalog_entries

ROOT = Path(__file__).resolve().parents[1]
entries = catalog_entries()
icons = (ROOT / "scripts/sera_item_icons.gd").read_text(encoding="utf-8")
stats = (ROOT / "scripts/sera_part_stats.gd").read_text(encoding="utf-8")
labstats = (ROOT / "scripts/sera_labo_stats.gd").read_text(encoding="utf-8")
save = (ROOT / "scripts/sera_save.gd").read_text(encoding="utf-8")
ci = (ROOT / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
workflow = (ROOT / ".github/workflows/sera-model-policy.yml").read_text(encoding="utf-8")
assert len(entries) == 19
assert 'const NATIVE_EQUIPMENT_DIRECTORY:' in icons
assert 'static func _native_equipment_icon(' in icons
assert 'var source: Texture2D = _native_equipment_icon(blueprint_id)' in icons
assert 'EQUIPMENT_INDICES' not in icons, "Retired image-only blueprints must not be active"
assert 'source = _frame(' not in icons, "No legacy matte equipment fallback"
assert 'static func complete_profile_text(' in labstats
assert 'for key in profile.keys():' in labstats
assert 'PROFILE_LABELS' in labstats
for slot, rig_set in [(e["slot"], e["rig_set"]) for e in entries.values()]:
    assert ('"'+slot+'"') in stats and ('"'+rig_set+'"') in stats, (slot, rig_set)
assert 'PrototypeCatalog.valid_uid(uid, blueprint)' in save
assert 'HANGER_LIMIT: int = 999' in save
assert 'Affixes.roll_five()' in save
assert 'gd tools/equipment_registry_runtime_check.gd' in ci
assert 'py tools/equipment_registry_self_check.py' in ci
assert 'sera_all_native_capture.gd' in workflow
assert 'tag_all_icons.py' in workflow
assert 'validate_all_icons.py' in workflow
print("SERA_ALL_EQUIPMENT_REGISTRY_STATIC_PASS", len(entries))
