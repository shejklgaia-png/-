#!/usr/bin/env python3
"""Approved BASE roof identities: eight recognizable silhouettes, same pads/lighting."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

src = read("scripts/sera_base_roof_identity.gd")
arch = read("scripts/sera_base_architecture.gd")
ci = read("tools/sera_ci_manifest.txt")
spec = {
    "NEXUS": ("NexusSteppedRoofCrown", "NexusRoofParapet"),
    "LABO": ("LabAsymmetricSailFlap", "LabTarpRidgeHoop"),
    "SCRAP_COLLECTOR": ("CollectorOpenGantryDeck", "CollectorGantryVoidRail"),
    "SMELTER": ("SmelterHeatDissipationFin", "SmelterStackCanopy"),
    "RECYCLER": ("RecyclerSplitJawRoof", "RecyclerRaisedGapTeeth"),
    "GENERATOR": ("GeneratorTurbineArchRib", "GeneratorSpineRail"),
    "STORAGE": ("StorageSteppedSteelLid", "StorageRaisedCargoHatch"),
    "BUILD_TERMINAL": ("TerminalCantileverRoofBlade", "TerminalSuspendedRoofBrace"),
}
assert 'const BaseRoofIdentity = preload("res://scripts/sera_base_roof_identity.gd")' in arch
assert 'BaseRoofIdentity.add_details(g, "NEXUS")' in arch
assert 'BaseRoofIdentity.add_details(g, key)' in arch
assert "g.detail_scale = 1.14" in arch
assert 'g.detail_scale = 1.45 if key == "LABO" else 1.55' in arch
for facility, features in spec.items():
    assert f'"{facility}"' in src, facility
    for feature in features:
        assert f'"{feature}"' in src, (facility, feature)
assert "static func add_details(" in src
assert "MultiMeshInstance3D.new()" not in src
assert "OmniLight3D.new()" not in src
assert "Area3D.new()" not in src
assert "py tools/base_roof_identity_self_check.py" in ci
assert "gd tools/base_roof_identity_runtime_check.gd" in ci
print("SERA_BASE_ROOF_IDENTITY_STATIC_PASS")
