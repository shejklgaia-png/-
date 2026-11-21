#!/usr/bin/env python3
"""Independent reference contract for the eight BASE architectural finishes."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

architecture = read("scripts/sera_base_architecture.gd")
polish = read("scripts/sera_base_reference_polish.gd")
floor = read("scripts/sera_base_floor_detail.gd")
hub = read("scripts/base_exploration.gd")
manifest = read("tools/sera_ci_manifest.txt")

# The additional geometry must be used at runtime, not left as a preview-only file.
assert 'preload("res://scripts/sera_base_reference_polish.gd")' in architecture
assert 'BasePolish.add_details(g, "NEXUS")' in architecture
assert "BasePolish.add_details(g, key)" in architecture
for key, feature in {
    "NEXUS": "NexusRoofParapetBraces",
    "LABO": "LabPrinterRail",
    "SCRAP_COLLECTOR": "CollectorHydraulicHose",
    "SMELTER": "FurnaceRetainerRing",
    "RECYCLER": "CrusherFeedRamp",
    "GENERATOR": "GeneratorCoolingFins",
    "STORAGE": "CargoCorrugatedDoors",
    "BUILD_TERMINAL": "BlueprintWireframeCrate",
}.items():
    assert ('"' + key + '"') in polish, key
    assert ('"' + feature + '"') in polish, feature

# All extra facility shapes are ordinary Batch geometry; do not generate
# individual mesh nodes, colliders, or animated objects for tiny details.
for call in ("g.box(", "g.rod(", "g.ring(", "g.box_tilt("):
    assert call in polish, call
assert "MeshInstance3D.new()" not in polish
assert "CollisionShape3D.new()" not in polish
assert 'BaseFloorDetail.decorate(floor, panels)' in hub
for feature in ("DeckPlateEdgeWelds", "DeckServiceScuffs",
                "DeckFastenerRows"):
    assert ('"' + feature + '"') in floor, feature
assert "if site_id.is_empty():" in floor, "facility pads must not be subdivided"
assert 'py tools/base_reference_polish_self_check.py' in manifest
assert 'gd tools/base_reference_polish_runtime_check.gd' in manifest
print("SERA_BASE_REFERENCE_POLISH_STATIC_PASS")
