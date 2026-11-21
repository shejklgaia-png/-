#!/usr/bin/env python3
"""Independent contract for the November 21 industrial base reference."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
def src(path):
    return (root / path).read_text(encoding="utf-8")
hub = src("scripts/base_exploration.gd")
devices = src("scripts/base_facility_system.gd")
architecture = src("scripts/sera_base_architecture.gd")
floor = src("scripts/sera_base_floor_detail.gd")
manifest = src("tools/sera_ci_manifest.txt")
assert 'const BaseArchitecture = preload("res://scripts/sera_base_architecture.gd")' in hub
assert 'const BaseArchitecture = preload("res://scripts/sera_base_architecture.gd")' in devices
assert 'const BaseFloorDetail = preload("res://scripts/sera_base_floor_detail.gd")' in hub
assert 'BaseFloorDetail.decorate(floor)' in hub
assert 'BaseArchitecture.build_nexus(nexus_building)' in hub
for key in ("LABO", "SCRAP_COLLECTOR", "SMELTER", "RECYCLER", "GENERATOR", "STORAGE", "BUILD_TERMINAL"):
    assert '"'+key+'"' in architecture
    assert 'BaseArchitecture.build_facility(root_node, key)' in devices
assert 'NEXUSBuilding' in hub and 'FacilitySign' in devices
assert 'MultiMeshInstance3D.new()' in architecture, "detail may not become hundreds of draw calls"
assert 'MultiMeshInstance3D.new()' in floor
for detail in ("ArmoredRoof", "GatePortal", "Canopy", "Crusher", "Furnace", "Claw", "Cargo", "Energy", "Blueprint"):
    assert detail in architecture, detail
for pattern in ("DrainGrates", "DeckBolts", "PanelSeams", "CautionStripes", "PowerConduits"):
    assert pattern in floor, pattern
# The image is a dense salvage workshop, not a set of clean box silhouettes.
for detail in ("NexusFacadeArmor", "NexusRoofServiceRack", "LabOpenWorkshop",
               "LabTaskLighting", "NexusAntennas", "ScrapYardSpareParts"):
    assert detail in architecture, detail
assert 'OmniLight3D.new()' in architecture, "warm workshop/furnace lighting must be real 3D illumination"
assert "STAGING_COLOR" not in architecture
assert 'cam.projection = Camera3D.PROJECTION_ORTHOGONAL' in hub
assert 'const HUB_SERA_CONTROLS_ENABLED: bool = false' in hub
assert 'py tools/base_reference_architecture_self_check.py' in manifest
assert 'gd tools/base_reference_architecture_runtime_check.gd' in manifest
print("SERA_BASE_REFERENCE_ARCHITECTURE_STATIC_PASS")
