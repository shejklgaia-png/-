#!/usr/bin/env python3
"""Night-base acceptance contract, independent of the current generated values."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def src(path):
    return (ROOT / path).read_text(encoding="utf-8")
architecture = src("scripts/sera_base_architecture.gd")
night = src("scripts/sera_base_night_facade.gd")
hub = src("scripts/base_exploration.gd")
props = src("scripts/sera_base_clutter.gd")
manifest = src("tools/sera_ci_manifest.txt")
assert 'const BaseNightFacade = preload("res://scripts/sera_base_night_facade.gd")' in architecture
assert 'BaseNightFacade.add_details(g, "NEXUS")' in architecture
assert 'BaseNightFacade.add_details(g, key)' in architecture
assert 'g.detail_scale = 1.14' in architecture, "NEXUS must not grow"
assert 'g.detail_scale = 1.28 if key == "LABO" else 1.36' in architecture
for name in (
    "NexusServiceFan", "LabCanopyCrest", "LabVentFan", "LabServiceDoor",
    "CollectorWeatherHood", "CollectorVentFan", "CollectorServiceDoor",
    "SmelterTallExhaust", "SmelterCoolingFan", "SmelterServiceDoor",
    "RecyclerRoofCowl", "RecyclerVentFan", "RecyclerServiceDoor",
    "GeneratorRoofShield", "GeneratorVentFan", "GeneratorServiceDoor",
    "StorageFabricCanopy", "StorageVentFan", "StorageLoadingDoor",
    "TerminalServiceRoof", "TerminalVentFan", "TerminalMaintenanceHatch",
):
    assert name in night, name
for name in ("CollectorTaskLight", "RecyclerWorkLight",
             "StorageLoadingLight", "TerminalWorkLight"):
    assert name in architecture, name
assert 'env.ambient_light_energy = 0.38' in hub
assert 'sun.light_energy = 0.36' in hub
assert 'lamp.shadow_enabled = false' in architecture
assert 'g.ring(' in night and 'g.rod(' in night and 'g.poly(' in night
assert 'MultiMeshInstance3D.new()' not in night
assert 'OmniLight3D.new()' not in night
assert 'var limit: float = 1.34' in props
assert 'py tools/base_night_facility_self_check.py' in manifest
assert 'gd tools/base_night_facility_runtime_check.gd' in manifest
print("SERA_BASE_NIGHT_FACILITY_STATIC_PASS")
