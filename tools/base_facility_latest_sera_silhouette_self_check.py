#!/usr/bin/env python3
"""BASE: 6px silhouette must literally use current SERA inverted hull;
the established 2px front/front sharp-corner renderer stays separate."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
get = lambda path: (root / path).read_text(encoding="utf-8")
sera = get("scripts/sera_view_edges.gd")
sera_shader = get("shaders/sera_view_edges.gdshader")
base = get("scripts/sera_base_facility_outlines.gd")
base_arch = get("scripts/sera_base_architecture.gd")
base_shader = get("shaders/base_facility_view_edges.gdshader")
motion = get("scripts/sera_base_facility_motion.gd")
vfx = get("scripts/sera_base_facility_vfx.gd")
manifest = get("tools/sera_ci_manifest.txt")
ci = get(".github/workflows/base-roof-visual-preview.yml")

# Reject stale 80-degree ribbon geometry accidentally used for the 6px pass.
assert "render_mode unshaded, cull_front, depth_draw_never;" in sera_shader
assert "SeraViewEdges._build_overlay" in base
assert 'preload("res://shaders/sera_view_edges.gdshader")' in base
assert '"stroke_px", 6.0' in base
assert 'Color("#55798A")' in base
assert "SeraViewEdges._position_key" in base
assert 'func crease_overlay_for' in base and 'func silhouette_overlay_for' in base
assert 'func silhouette_material' in base and 'func crease_material' in base
assert "SurfaceTool.CUSTOM_RGBA_FLOAT" in base
assert "fa.dot(fb)" in base
assert "cos(deg_to_rad(80.0))" in base
assert "inverted_hull" in sera
assert "normal_sum" in sera
assert "cull_front" not in base_shader
assert "uniform float crease_px" in base_shader
assert "both_front && COLOR.a > 0.5" in base_shader
assert "uniform bool crease_only = false" in base_shader
assert "contour && !crease_only" in base_shader
assert '"crease_only", true' in base
assert '"crease_px", 2.0' in base

assert "ArchitecturalEdgeInk_" in base_arch
assert "ArchitecturalCreaseInk_" in base_arch
assert "silhouette_overlay_for(" in base_arch
assert "crease_overlay_for(" in base_arch
assert "silhouette_material()" in base_arch
assert "crease_material()" in base_arch
assert 'tint not in ["blue_light", "amber_light", "amber", "glass"]' in base_arch
assert 'record.has("ink_mesh")' in motion
assert 'record.has("crease_mesh")' in motion
assert "crease_mesh.set_instance_transform" in motion
assert '"FX_NO_OUTLINE"' in vfx
assert "py tools/base_facility_latest_sera_silhouette_self_check.py" in manifest
assert "gd tools/base_facility_latest_sera_silhouette_runtime_check.gd" in manifest
assert "base_facility_latest_sera_silhouette_runtime_check.gd" in ci

# No SERA actor stroke or topology changes are allowed.
assert 'set_shader_parameter("stroke_px", 3.0)' in sera
assert 'Color("#17212f")' in sera
print("SERA_BASE_LATEST_SILHOUETTE_STATIC_PASS 6px current SERA hull; 2px unchanged crease")
