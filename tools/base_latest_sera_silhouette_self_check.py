#!/usr/bin/env python3
"""BASE: same SERA 2026-11-22 inverted hull for 6px, previous 2px crease."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
sera = (root / "shaders/sera_view_edges.gdshader").read_text(encoding="utf-8")
sera_generator = (root / "scripts/sera_view_edges.gd").read_text(encoding="utf-8")
ink = (root / "scripts/sera_base_facility_outlines.gd").read_text(encoding="utf-8")
creases = (root / "scripts/sera_base_facility_crease_geometry.gd").read_text(encoding="utf-8")
crease_shader = (root / "shaders/base_facility_view_edges.gdshader").read_text(encoding="utf-8")
arch = (root / "scripts/sera_base_architecture.gd").read_text(encoding="utf-8")
motion = (root / "scripts/sera_base_facility_motion.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
workflow = (root / ".github/workflows/base-roof-visual-preview.yml").read_text(encoding="utf-8")
capture = (root / "tools/base_isometric_visual_capture.gd").read_text(encoding="utf-8")
assert "cull_front" in sera and "depth_draw_never" in sera
assert "_build_overlay(mesh: Mesh)" in sera_generator
assert "normal_sum" in sera_generator and "vertex_normals" in sera_generator
# SERA's own normal recipe and fast 3px path remain unchanged; only BASE
# inverts the companion normals because BASE source winding is clockwise.
assert "var face_normal: Vector3 = (b - a).cross(c - a)" in sera_generator
assert "outward_normals[i] = -outward_normals[i]" in ink
assert "arrays[Mesh.ARRAY_NORMAL] = outward_normals" in ink
assert "base_hull.add_surface_from_arrays" in ink
assert "no internal polygon" in sera or "backfaces" in sera
assert 'preload("res://shaders/sera_view_edges.gdshader")' in ink
assert "SeraViewEdges._build_overlay(physical_mesh)" in ink
assert '"stroke_px", 6.0' in ink
assert 'hint_range(0.5, 8.0)' in sera
assert 'depth_probe_px = stroke_px > 4.0 ? stroke_px * 1.5 : stroke_px;' in sera
assert 'Color("#000000")' in ink
assert 'Color("#353535")' in ink
assert 'Color("#55798A")' not in ink
assert 'preload("res://shaders/base_facility_view_edges.gdshader")' in ink
assert "BaseFacilityCreaseGeometry._build_overlay" in ink
assert '"crease_px", 2.0' in ink
assert "crease_material()" in ink
assert "CREASE_DEGREES: float = 80.0" in creases
assert "_extract_edges(mesh: Mesh)" in creases
assert "SurfaceTool.CUSTOM_RGBA_FLOAT" in creases
assert "edge" in creases
assert "both_front && COLOR.a > 0.5" in crease_shader
assert "bool visible = foreground_crease;" in crease_shader
assert "float width = crease_px;" in crease_shader
assert "ArchitecturalEdgeInk_" in arch
assert "ArchitecturalCreaseInk_" in arch
assert "outline_crease_meshes_by_bucket" in arch
assert "ink_mesh" in arch and "crease_mesh" in arch
assert 'record.has("crease_mesh")' in motion
assert 'crease_mesh.set_instance_transform' in motion
assert "Geometry2D.convex_hull" not in ink
assert 'py tools/base_latest_sera_silhouette_self_check.py' in manifest
assert 'gd tools/base_latest_sera_silhouette_runtime_check.gd' in manifest
assert "base_latest_sera_silhouette_runtime_check.gd" in workflow
# Detect a visible output regression in an actual 720x1280 framebuffer:
# hiding only the 6px pass must remove a measurable number of black pixels.
assert "SERA_BASE_ASSERT_OUTLINES" in capture
assert "ArchitecturalEdgeInk_" in capture
assert "visible_stroke_pixels" in capture
assert "SERA_BASE_VISIBLE_6PX_PIXELS_PASS" in capture
assert 'SERA_BASE_ASSERT_OUTLINES: "1"' in workflow
print("SERA_BASE_LATEST_HULL_6PX_PRESERVED_CREASE_2PX_STATIC_PASS")
