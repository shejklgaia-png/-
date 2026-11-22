#!/usr/bin/env python3
"""Regress BASE's actual view-dependent SERA-class shader, not 2D wire cages."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
hub = (root / "scripts/base_exploration.gd").read_text(encoding="utf-8")
arch = (root / "scripts/sera_base_architecture.gd").read_text(encoding="utf-8")
edge = (root / "scripts/sera_base_facility_outlines.gd").read_text(encoding="utf-8")
shader = (root / "shaders/base_facility_view_edges.gdshader").read_text(encoding="utf-8")
silhouette = (root / "shaders/base_facility_silhouette_edges.gdshader").read_text(encoding="utf-8")
motion = (root / "scripts/sera_base_facility_motion.gd").read_text(encoding="utf-8")
vfx = (root / "scripts/sera_base_facility_vfx.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
workflow = (root / ".github/workflows/base-roof-visual-preview.yml").read_text(encoding="utf-8")

assert "extends RefCounted" in edge
assert "BaseFacilityCreaseGeometry._build_overlay(physical_mesh)" in edge
assert "ShaderMaterial.new()" in edge
assert '"stroke_px", 4.0' in edge
assert 'preload("res://shaders/base_facility_silhouette_edges.gdshader")' in edge
assert '"crease_px", 1.0' in edge
assert 'Color("#000000")' in edge
assert 'Color("#202020")' in edge
assert 'Color("#55798A")' not in edge
assert "RENDER_ORDER.DEPTH_TESTED_EMISSIVE" in edge
assert "Geometry2D.convex_hull" not in edge
assert "draw_polyline" not in edge
assert "draw_line(" not in edge

assert "uniform float silhouette_px" not in shader
assert "render_mode unshaded, cull_disabled, depth_draw_never;" in silhouette
assert "float stroke_px : hint_range(0.5, 9.0) = 4.0" in silhouette
assert "bool contour = boundary && a_facing > 0.02;" in silhouette
assert "a_facing > 0.02 && b_facing < -0.02" in silhouette
assert "b_facing > 0.02 && a_facing < -0.02" in silhouette
assert "bool visible = contour || force_all_edges;" in silhouette
assert "hint_depth_texture" not in silhouette
assert "CUSTOM0.xyz" in silhouette and "COLOR.rgb" in silhouette
assert "POSITION = clip;" in silhouette and "ALPHA = 1.0;" in silhouette
assert "depth_test_disabled" not in silhouette
assert "vec3 normal_a = -normalize" in shader
assert "vec3 n_b = -normalize" in shader
assert "uniform float crease_px : hint_range(0.5, 6.0) = 1.0" in shader
assert "CUSTOM0.xyz" in shader and "COLOR.a" in shader
assert "a_facing > 0.02 && b_facing > 0.02" in shader
assert "bool visible = foreground_crease;" in shader
assert "float width = crease_px;" in shader
assert "both_front && COLOR.a > 0.5" in shader
assert "POSITION = clip" in shader
assert "VIEWPORT_SIZE" in shader
assert "discard;" in shader
assert "depth_test_disabled" not in shader
assert "depth_draw_never" in shader
assert "ALPHA = 1.0" in shader

assert "FacilityOutlines" not in hub
assert "SeraBaseFacilityOutlines" not in hub
assert "outline_meshes_by_bucket" in arch
assert "ArchitecturalEdgeInk_" in arch
assert "ArchitecturalCreaseInk_" in arch
assert 'tint not in ["blue_light", "amber_light", "amber", "glass"]' in arch
assert 'set_meta("FX_NO_OUTLINE", true)' in arch
assert "ink_mesh" in arch and "ink_index" in arch
assert 'record.has("ink_mesh")' in motion
assert 'ink_mesh.set_instance_transform' in motion
assert 'crease_mesh.set_instance_transform' in motion
assert 'set_meta("FX_NO_OUTLINE", true)' in vfx
assert 'py tools/base_facility_mesh_edge_shader_self_check.py' in manifest
assert 'gd tools/base_facility_mesh_edge_shader_runtime_check.gd' in manifest
assert 'base_facility_mesh_edge_shader_runtime_check.gd' in workflow
print("SERA_BASE_MESH_EDGE_SHADER_STATIC_PASS")
