#!/usr/bin/env python3
"""BASE approved shape refit: stepped/sloped silhouettes and LABO down by ~22px."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
arch = (root/"scripts/sera_base_architecture.gd").read_text(encoding="utf-8")
mass = (root/"scripts/sera_base_structural_mass.gd").read_text(encoding="utf-8")
night = (root/"scripts/sera_base_night_facade.gd").read_text(encoding="utf-8")
fac = (root/"scripts/base_facility_system.gd").read_text(encoding="utf-8")
manifest = (root/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert '"id": "LABO", "name": "LABO", "at": Vector3(7.15, 0.0, 6.95)' in fac
assert 'const BaseStructuralMass = preload("res://scripts/sera_base_structural_mass.gd")' in arch
assert 'BaseStructuralMass.add_details(g, "NEXUS")' in arch
assert 'BaseStructuralMass.add_details(g, key)' in arch
assert 'g.detail_scale = 1.14' in arch, "NEXUS must not be enlarged"
assert 'g.detail_scale = 1.45 if key == "LABO" else 1.55' in arch
# Approved no-enlargement constraint: preserve existing architecture scales.
assert 'g.detail_scale = 1.14' in arch
for feature in (
    "NexusCornerButtress", "NexusRoofGutter",
    "LabAFrameRidge", "LabAngledSideRoof", "LabRollUpServiceBay",
    "CollectorCraneCounterweight", "CollectorDiagonalArmBrace",
    "SmelterSecondaryExhaust", "SmelterWindBaffle",
    "RecyclerSplayedArmorJaw", "RecyclerCantedCowl",
    "GeneratorExternalCoolingDrum", "GeneratorRibbedTurbineGuard",
    "StorageRaisedLoadingFrame", "StorageTarpSaddle",
    "TerminalSlopedRoofWing", "TerminalToolHatch",
    "LabCanopyStitch", "LabVentBlade", "SmelterExhaustHeatBand",
    "GeneratorCoolingIntakeGrille", "StorageTarpTieDown",
    "TerminalHatchStatusStrip",
):
    assert feature in mass, feature
for roof in ("LabCanopyCrest", "CollectorWeatherHood",
             "RecyclerRoofCowl", "StorageFabricCanopy",
             "TerminalServiceRoof"):
    assert 'g.poly_tilt("' + roof + '"' in night, roof
assert 'g.poly_tilt(' in mass and 'g.box_tilt(' in mass
assert 'MultiMeshInstance3D.new()' not in mass
assert 'OmniLight3D.new()' not in mass
assert 'py tools/base_structural_mass_self_check.py' in manifest
assert 'gd tools/base_structural_mass_runtime_check.gd' in manifest
print("SERA_BASE_STRUCTURAL_MASS_STATIC_PASS")
