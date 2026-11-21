#!/usr/bin/env python3
"""BASE roof readability contract: exposed machines and one clear silhouette per use."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

src = read("scripts/sera_base_roof_identity.gd")
arch = read("scripts/sera_base_architecture.gd")
night = read("scripts/sera_base_night_facade.gd")
mass = read("scripts/sera_base_structural_mass.gd")
ci = read("tools/sera_ci_manifest.txt")

spec = {
    "NEXUS": ("NexusRoofCommandStripe", "NexusEntranceDirectionBand", "NexusDoorOuterFrame"),
    "LABO": ("LabSingleSlopeCanopy", "LabSideRoll", "LabPrinterToolhead", "LabFocalPrintBed"),
    "SCRAP_COLLECTOR": ("CollectorOpenBoomCrossbar", "CollectorCraneMarker", "CollectorOpenClawJaw", "CollectorRaisedJib", "CollectorClawSignalCheek"),
    "SMELTER": ("SmelterHeatShieldRib", "SmelterHeatVent", "SmelterStackHeatCollar"),
    "RECYCLER": ("RecyclerSideRoofShutter", "RecyclerOpenThroatRail", "RecyclerOpenVFeedRail", "RecyclerOpposedJawFace"),
    "GENERATOR": ("GeneratorTurbineHoop", "GeneratorPowerSpine", "GeneratorCoreCorona"),
    "STORAGE": ("StorageContainerRoof", "StorageRoofRidge", "StorageLoadingHeader"),
    "BUILD_TERMINAL": ("TerminalSlimDataVisor", "TerminalVisorBracket", "TerminalScanFrameSide"),
}
for key, expected in spec.items():
    assert f'"{key}"' in src, key
    for feature in expected:
        assert f'"{feature}"' in src, (key, feature)
# The earlier layered design is revoked, not piled underneath.
for former in (
    "NexusSteppedRoofCrown", "LabAsymmetricSailFlap",
    "CollectorOpenGantryDeck", "SmelterHeatDissipationFin",
    "RecyclerSplitJawRoof", "GeneratorTurbineArchRib",
    "StorageSteppedSteelLid", "TerminalCantileverRoofBlade"
):
    assert former not in src, f"oversized old roof still authored: {former}"
assert 'BaseRoofIdentity.add_details(g, "NEXUS")' in arch
assert 'BaseRoofIdentity.add_details(g, key)' in arch
assert 'g.detail_scale = 1.14' in arch
assert 'g.detail_scale = 1.45 if key == "LABO" else 1.55' in arch
# Prior broad pitched shells now shrink to accents behind exposed machine faces.
for name in ("LabCanopyCrest", "CollectorWeatherHood",
             "RecyclerRoofCowl", "GeneratorRoofShield",
             "StorageFabricCanopy", "TerminalServiceRoof"):
    assert name in night
for name in ("LabAngledSideRoof", "CollectorSortingRoofFin",
             "RecyclerCantedCowl", "StorageTarpSaddle", "TerminalSlopedRoofWing"):
    assert name in mass
assert "MultiMeshInstance3D.new()" not in src
assert "OmniLight3D.new()" not in src
assert "Area3D.new()" not in src
assert "py tools/base_roof_identity_self_check.py" in ci
assert "gd tools/base_roof_identity_runtime_check.gd" in ci
print("SERA_BASE_ROOF_CLARITY_STATIC_PASS")
