#!/usr/bin/env python3
"""2026-11-22: wholly rebuilt BASE exterior, archived original preserved.
Independent acceptance contract agreed before production implementation.
"""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
def read(path: str) -> str:
    return (root / path).read_text(encoding="utf-8")
arch = read("scripts/sera_base_architecture.gd")
fresh = read("scripts/sera_base_fresh_design.gd")
hub = read("scripts/base_exploration.gd")
manifest = read("tools/sera_ci_manifest.txt")
workflow = read(".github/workflows/base-roof-visual-preview.yml")
doc = read("docs/agent/BASE_VISUAL_REVIEW.md")
for constant in (
    "const BASE_ORTHO_SIZE: float = 38.0",
    "const BASE_CAMERA_POSITION: Vector3 = Vector3(21.0, 19.5, 25.0)",
    "const BASE_CAMERA_TARGET: Vector3 = Vector3(0.0, 2.1, -2.2)",
):
    assert constant in hub, constant
assert 'const BaseFreshDesign = preload("res://scripts/sera_base_fresh_design.gd")' in arch
assert 'const ACTIVE_BASE_MODEL: String = "FRESH_20261122"' in arch
assert 'BaseFreshDesign.add_details(g, "NEXUS")' in arch
assert "BaseFreshDesign.add_details(g, key)" in arch
assert 'node.set_meta("base_design", ACTIVE_BASE_MODEL)' in arch
# Existing code remains in archive; active path must *never* call legacy layers.
assert "if ACTIVE_BASE_MODEL == \"FRESH_20261122\":" in arch
assert 'static func add_details(g: Variant, key: String) -> void:' in fresh
for name in (
    "NEXUS", "LABO", "SCRAP_COLLECTOR", "SMELTER",
    "RECYCLER", "GENERATOR", "STORAGE", "BUILD_TERMINAL",
):
    assert f'\"{name}\": _' in fresh, name
# Major architectural signatures must be DIFFERENT, not generic grey boxes.
for name in (
    "FreshNexusSplitCrown", "FreshNexusGateCore",
    "FreshLabOpenPrinterBridge", "FreshLabFabricationBed",
    "FreshCollectorTallBoom", "FreshCollectorOpenGrip",
    "FreshSmelterTwinStacks", "FreshSmelterHotThroat",
    "FreshRecyclerOpenVJaws", "FreshRecyclerRoller",
    "FreshGeneratorFrontRotor", "FreshGeneratorBlueCorona",
    "FreshStorageOffsetStacks", "FreshStorageLoadingLift",
    "FreshTerminalWideScreen", "FreshTerminalSignalMast",
):
    assert name in fresh, name
assert "py tools/base_fresh_rebuild_self_check.py" in manifest
assert "gd tools/base_fresh_rebuild_runtime_check.gd" in manifest
assert "'scripts/sera_base_fresh_design.gd'" in workflow
assert "python3 tools/base_fresh_rebuild_self_check.py" in workflow
assert "tools/base_fresh_rebuild_runtime_check.gd" in workflow
assert "archive/base-models-20261122-before-rebuild" in doc
# New meshes still share the game's existing batch engine; avoid one MeshInstance per bolt.
for invalid in ["MeshInstance3D.new()", "MultiMeshInstance3D.new()", "OmniLight3D.new()", "CollisionShape3D.new()"]:
    assert invalid not in fresh, invalid
print("SERA_BASE_FRESH_REBUILD_STATIC_PASS")
