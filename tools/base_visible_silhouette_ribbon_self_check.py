#!/usr/bin/env python3
"""Regression: BASE 4px must draw only true camera contours, never entire faces."""
from pathlib import Path
r = Path(__file__).resolve().parents[1]
s = (r/"scripts/sera_base_facility_outlines.gd").read_text(encoding="utf-8")
shader = (r/"shaders/base_facility_silhouette_edges.gdshader").read_text(encoding="utf-8")
creases = (r/"scripts/sera_base_facility_crease_geometry.gd").read_text(encoding="utf-8")
corner = (r/"shaders/base_facility_view_edges.gdshader").read_text(encoding="utf-8")
workflow = (r/".github/workflows/base-roof-visual-preview.yml").read_text(encoding="utf-8")
capture = (r/"tools/base_isometric_visual_capture.gd").read_text(encoding="utf-8")
manifest = (r/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert "BaseFacilityCreaseGeometry._build_overlay(physical_mesh)" in s
assert 'preload("res://shaders/base_facility_silhouette_edges.gdshader")' in s
assert "SeraViewEdges._build_overlay(physical_mesh)" not in s
assert 'Color("#000000")' in s and '"stroke_px", 4.0' in s
assert 'Color("#000000")' in s and '"crease_px", 2.0' in s
assert "crease_for(geometry:" in s and "overlay_for(geometry:" in s
assert "CUSTOM_RGBA_FLOAT" in creases and "_extract_edges(mesh: Mesh)" in creases
assert "float stroke_px : hint_range(0.5, 9.0) = 4.0;" in shader
assert "bool contour = boundary && a_facing > 0.02;" in shader
assert "a_facing > 0.02 && b_facing < -0.02" in shader
assert "b_facing > 0.02 && a_facing < -0.02" in shader
assert "bool visible = contour || force_all_edges;" in shader
assert "vec3 normal_a = -normalize" in shader
assert "render_mode unshaded, cull_disabled, depth_draw_never;" in shader
assert "hint_depth_texture" not in shader
assert "ALPHA = 1.0;" in shader and "POSITION = clip;" in shader
assert "bool foreground_crease = both_front && COLOR.a > 0.5;" in corner
assert "float width = crease_px;" in corner
assert "vec3 normal_a = -normalize" in corner
assert "SERA_BASE_ASSERT_OUTLINES" in capture and "visible_stroke_pixels" in capture
assert "base_visible_silhouette_ribbon_runtime_check.gd" in workflow
assert "py tools/base_visible_silhouette_ribbon_self_check.py" in manifest
assert "gd tools/base_visible_silhouette_ribbon_runtime_check.gd" in manifest
print("BASE_VISIBLE_CONTOUR_RIBBON_STATIC_PASS")
