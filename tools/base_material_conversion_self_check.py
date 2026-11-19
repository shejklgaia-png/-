#!/usr/bin/env python3
"""Material conversion UI/persistence static contract and CI registration."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def file(name): return (ROOT/name).read_text(encoding="utf-8")
base=file("scripts/base_facility_system.gd")
rules=file("scripts/sera_base_materials.gd")
save=file("scripts/sera_save.gd")
manifest=file("tools/sera_ci_manifest.txt")
assert 'res://scripts/sera_base_materials.gd' in base
assert 'res://scripts/sera_base_materials.gd' in save
assert 'func convert_material(' in save
assert 'func get_material_inventory(' in save
assert 'func meets_requirements(' in rules
assert 'func convert(' in rules
assert 'func _show_conversion(' in base
assert 'func _perform_conversion(' in base
assert '"SMELTER"' in base and '"RECYCLER"' in base
assert "gd tools/base_material_conversion_runtime_check.gd" in manifest
print("SERA_BASE_MATERIAL_STATIC_PASS")
