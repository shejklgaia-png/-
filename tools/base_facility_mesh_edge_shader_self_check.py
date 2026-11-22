#!/usr/bin/env python3
"""Regress BASE's actual view-dependent SERA-class shader, not 2D wire cages."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
hub = (root / "scripts/base_exploration.gd").read_text(encoding="utf-8")
arch = (root / "scripts/sera_base_architecture.gd").read_text(encoding="utf-8")
edge = (root / "scripts/sera_base_facility_outlines.gd").read_text(encoding="utf-8")
shader = (root / "shaders/base_facility_view_edges.gdshader").read_text(encoding="utf-8")
sera_shader = (root / "shaders/sera_view_edges.gdshader").read_text(encoding="utf-8")
motion = (root / "scripts/sera_base_facility_motion.gd").read_text(encoding="utf-8")
vfx = (root / "scripts/sera_base_facility_vfx.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
workflow = (root / ".github/workflows/base-roof-visual-preview.yml").read_text(encoding="utf-8")

assert "extends RefCounted" in edge
assert "SeraViewEdges._build_overlay" in edge
assert "ShaderMaterial.new()" in edge
assert 'SERA_SILHOUETTE = preload("res://shaders/sera_view_edges.gdshader")' in edge
assert 'BASE_CREASE_SHADER = preload("res://shaders/base_facility_view_edges.gdshader")' in edge
assert '"stroke_px", 6.0' in edge
assert '"crease_px", 2.0' in edge
assert 'Color("#000000")' in edge
assert 'Color("#353535")' in edge
assert "crease_overlay_for" in edge
assert "_extract_edges" in edge and "SurfaceTool.CUSTOM_RGBA_FLOAT" in edge
assert "if not bool(edge.get(\"crease\", false)) or not edge.has(\"face_b\"):" in edge
assert "RENDER_ORDER.DEPTH_TESTED_EMISSIVE" in edge
assert "Geometry2D.convex_hull" not in edge
assert "draw_polyline" not in edge
assert "draw_line(" not in edge

# The 6px pass must use the exact current SERA visible-mesh hull shader.
assert "cull_front" in sera_shader and "stroke_px" in sera_shader
assert "CUSTOM0" not in sera_shader and "a_facing" not in sera_shader
assert "depth_test_disabled" not in sera_shader and "depth_draw_never" in sera_shader
# The independent 2px pass keeps only real front/front polygon creases.
assert "uniform float crease_px" in shader
assert "CUSTOM0.xyz" in shader and "COLOR.a" in shader
assert "a_facing > 0.02 && b_facing > 0.02" in shader
assert "both_front && COLOR.a > 0.5" in shader
assert "contour" not in shader and "silhouette_px" not in shader
assert "POSITION = clip" in shader and "VIEWPORT_SIZE" in shader
assert "discard;" in shader and "depth_test_disabled" not in shader
assert "depth_draw_never" in shader and "ALPHA = 1.0" in shader

assert "FacilityOutlines" not in hub
assert "SeraBaseFacilityOutlines" not in hub
assert "outline_meshes_by_bucket" in arch
assert "ArchitecturalEdgeInk_" in arch and "ArchitecturalCreaseInk_" in arch
assert 'tint not in ["blue_light", "amber_light", "amber", "glass"]' in arch
assert 'set_meta("FX_NO_OUTLINE", true)' in arch
assert "ink_mesh" in arch and "ink_index" in arch
assert "crease_mesh" in arch and "crease_index" in arch
assert 'record.has("ink_mesh")' in motion
assert 'ink_mesh.set_instance_transform' in motion
assert 'crease_mesh.set_instance_transform' in motion
assert 'set_meta("FX_NO_OUTLINE", true)' in vfx
assert 'py tools/base_facility_mesh_edge_shader_self_check.py' in manifest
assert 'gd tools/base_facility_mesh_edge_shader_runtime_check.gd' in manifest
assert 'base_facility_mesh_edge_shader_runtime_check.gd' in workflow
print("SERA_BASE_MESH_EDGE_SHADER_STATIC_PASS")
