#!/usr/bin/env python3
"""Direct polygon-sculpt contract for BASE, independent of engine implementation."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def get(name): return (ROOT / name).read_text(encoding="utf-8")

meshes = get("scripts/sera_base_polygon_meshes.gd")
arch = get("scripts/sera_base_architecture.gd")
polish = get("scripts/sera_base_reference_polish.gd")
hub = get("scripts/base_exploration.gd")
ci = get("tools/sera_ci_manifest.txt")

# A proper authored triangle surface with normals/UVs; dressing cubes alone
# is not an acceptable implementation of this request.
for item in ("SurfaceTool.new()", "Mesh.PRIMITIVE_TRIANGLES",
             "st.set_normal(", "st.set_uv(", "st.add_vertex(",
             "func _triangle(", "func _beveled(", "func _hopper(",
             "func _canvas(", "func _rotor(", "func _hood("):
    assert item in meshes, item
for kind in ('"deck"', '"bevel"', '"hopper"', '"hood"',
             '"canvas"', '"drum"', '"gear"'):
    assert kind in meshes, kind
assert 'const BasePolygon = preload("res://scripts/sera_base_polygon_meshes.gd")' in arch
assert 'const BasePolygon = preload("res://scripts/sera_base_polygon_meshes.gd")' in hub
assert "BasePolygon.make(geometry)" in arch
assert 'var plate_mesh: ArrayMesh = BasePolygon.make("deck")' in hub
assert 'g.poly(' in arch, "actual primary structure must be polygon mesh"
assert 'g.poly(' in polish, "all eight models must use the polygon sculpt"
for feature in (
    "NexusCutCornerShell", "LabDrapedCanopy",
    "CollectorFunnel", "FurnaceOctagonalBody", "CrusherCutterDrum",
    "GeneratorRadialRotor", "CargoChamferedContainer",
    "BlueprintAngledHood",
):
    assert feature in arch + polish, feature
assert 'static var _mesh_cache: Dictionary = {}' in meshes, (
    "The shared polygon mesh cache must be declared before make() uses it")
assert 'for point in [a, c, b]:' in meshes, (
    "Godot treats CLOCKWISE triangles as front faces; do not cull the shell")
assert 'py tools/base_polygon_geometry_self_check.py' in ci
assert 'gd tools/base_polygon_geometry_runtime_check.gd' in ci
# The historical deck checks must validate the new authored polygons rather
# than reject them because the surface is no longer a BoxMesh.
assert "ArrayMesh" in get("tools/base_uneven_deck_runtime_check.gd")
assert 'BasePolygon.make("deck")' in get("tools/base_uneven_deck_self_check.py")
print("SERA_BASE_POLYGON_GEOMETRY_STATIC_PASS")
