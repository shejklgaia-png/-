#!/usr/bin/env python3
"""SERA: the 80-degree view-dependent hard-edge/contour visual contract."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
script = (root / "scripts/sera_view_edges.gd").read_text(encoding="utf-8")
shader = (root / "shaders/sera_view_edges.gdshader").read_text(encoding="utf-8")
rig = (root / "scripts/sera_rig.gd").read_text(encoding="utf-8")
boss = (root / "scripts/bittaran_rig.gd").read_text(encoding="utf-8")
target = (root / "scripts/main.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
assert "const CREASE_DEGREES: float = 80.0" in script
assert '_ink_material.set_shader_parameter("stroke_px", 3.0)' in script
assert "uniform float stroke_px : hint_range(0.5, 4.0) = 3.0;" in shader
assert "cos(deg_to_rad(CREASE_DEGREES))" in script
assert "Mesh.PRIMITIVE_TRIANGLES" in script
assert "var adjacent := Color(" in script, "SurfaceTool.set_custom() needs a Color, not Vector4"
assert "_extract_edges" in script and "_build_overlay" in script
assert "edge[\"face_b\"]" in script
assert "mesh.get_surface_count()" in script
assert "mesh.surface_get_arrays" in script
# FX exclusion must cover the full parent chain, not only a source mesh name.
# Real v85 Swordeffect's AlphaClippedMainArc/ConvexTwoSided3DArc children
# have neutral mesh names under the Slash effect root.
assert "func _is_eligible(" in script
assert "func _is_fx_node(" in script
assert "var ancestor: Node = source" in script
assert "ancestor = ancestor.get_parent()" in script
assert 'get_meta("sera_no_view_edges", false)' in script
assert 'source.get_active_material(surface)' in script
assert "BaseMaterial3D.TRANSPARENCY_DISABLED" in script
assert "func _remove_overlay(" in script
assert "_remove_overlay(source)" in script
trail = (root / "scripts/sword_trail.gd").read_text(encoding="utf-8")
back_thruster = (root / "scripts/back_thruster_fx.gd").read_text(encoding="utf-8")
assert 'effect_root.set_meta("sera_no_view_edges", true)' in trail
assert 'set_meta("sera_no_view_edges", true)' in back_thruster
assert "func _process(" in script and "SCAN_INTERVAL" in script
assert "OUTLINE_SCRIPT.new()" in rig and "OUTLINE_SCRIPT.new()" in boss
assert "OUTLINE_SCRIPT.new()" in target
assert "shader_type spatial;" in shader
assert "depth_draw_never" in shader
assert "depth_test_disabled" not in shader
assert "CAMERA_POSITION_WORLD" in shader and "VIEWPORT_SIZE" in shader
assert "CUSTOM0" in shader and "PROJECTION_MATRIX" in shader
# v530 visual correction: a 90-degree corner with BOTH sides facing the
# camera must never get a line. Ink only at the visible projected contour,
# including an occluding near-part silhouette.
assert "bool hard_crease" not in shader
assert "COLOR.a > 0.5" not in shader
assert "visible = silhouette;" in shader
assert "a_facing > 0.02 && b_facing < -0.02" in shader
assert "b_facing > 0.02 && a_facing < -0.02" in shader
assert "bool visible = boundary && a_facing > 0.02;" in shader
assert "discard;" in shader
# Ink must be in the transparent pass (AFTER opaque armor), but still
# participate in normal depth testing. Otherwise draw-order can erase lines.
assert "ALPHA = 1.0;" in shader
assert "RENDER_ORDER.DEPTH_TESTED_EMISSIVE" in script
assert 'const RENDER_ORDER = preload("res://scripts/render_order_policy.gd")' in script
assert "py tools/sera_view_edges_self_check.py" in manifest
assert "gd tools/sera_view_edges_runtime_check.gd" in manifest
print("SERA_VIEW_EDGES_STATIC_PASS")
