#!/usr/bin/env python3
"""BASE silhouette refinement: independent acceptance contract."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def src(p): return (ROOT/p).read_text(encoding="utf-8")
arch = src("scripts/sera_base_architecture.gd")
polys = src("scripts/sera_base_polygon_meshes.gd")
detail = src("scripts/sera_base_silhouette_refinement.gd")
hub = src("scripts/base_exploration.gd")
ci = src("tools/sera_ci_manifest.txt")

# These are different physically modelled silhouettes, not boxes over old boxes.
for kind in ('"roof"', '"louver"'):
    assert kind in polys
assert 'static func _roof(' in polys
assert 'static func _louver(' in polys
assert 'const BaseSilhouette = preload("res://scripts/sera_base_silhouette_refinement.gd")' in arch
assert 'BaseSilhouette.add_details(g, "NEXUS")' in arch
assert 'BaseSilhouette.add_details(g, key)' in arch
for facility, feature in {
    "NEXUS": "NexusGabledEntranceShelter",
    "LABO": "LabFabricCanopyRail",
    "SCRAP_COLLECTOR": "CollectorOpenGearHousing",
    "SMELTER": "FurnaceExhaustCowling",
    "RECYCLER": "CrusherLouveredDriveCase",
    "GENERATOR": "GeneratorFinnedVentFace",
    "STORAGE": "CargoShelterRoof",
    "BUILD_TERMINAL": "BlueprintShelteredMonitor",
}.items():
    assert '"'+facility+'"' in detail, facility
    assert '"'+feature+'"' in detail, feature

assert 'g.poly(' in detail and 'g.poly_tilt(' in detail
assert 'MeshInstance3D.new()' not in detail
assert 'CollisionShape3D.new()' not in detail
assert 'OmniLight3D.new()' not in detail
assert 'if _mesh_cache.has(kind)' in polys
assert 'st.set_color(Color(' in polys, "Direct triangle vertices need baked face contrast"
assert 'surface.vertex_color_use_as_albedo = ' in arch, "Use polygon colors"
assert 'mat.vertex_color_use_as_albedo = true' in hub, "Deck bevels need baked face contrast"
assert 'BaseDeckLayout.generate(' in hub, "do not change facility reserved slabs"
assert 'py tools/base_silhouette_refinement_self_check.py' in ci
assert 'gd tools/base_silhouette_refinement_runtime_check.gd' in ci
print("SERA_BASE_SILHOUETTE_REFINEMENT_STATIC_PASS")
