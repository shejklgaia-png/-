#!/usr/bin/env python3
"""SERA: visible per-mesh contour ink, without internal polygon crease lines."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
script = (root / "scripts/sera_view_edges.gd").read_text(encoding="utf-8")
shader = (root / "shaders/sera_view_edges.gdshader").read_text(encoding="utf-8")
rig = (root / "scripts/sera_rig.gd").read_text(encoding="utf-8")
boss = (root / "scripts/bittaran_rig.gd").read_text(encoding="utf-8")
target = (root / "scripts/main.gd").read_text(encoding="utf-8")
manifest = (root / "tools/sera_ci_manifest.txt").read_text(encoding="utf-8")

# Approved: keep the original 3px dark outline, on SERA + training target + boss,
# but render per-MeshInstance visible silhouettes only (like the IRIS comparison).
assert '_ink_material.set_shader_parameter("stroke_px", 3.0)' in script
assert 'uniform float stroke_px : hint_range(0.5, 4.0) = 3.0;' in shader
assert 'Color("#17212f")' in script
assert '"SeraEdgeInk"' in script
assert 'OUTLINE_SCRIPT.new()' in rig and 'OUTLINE_SCRIPT.new()' in boss
assert 'OUTLINE_SCRIPT.new()' in target
assert 'Mesh.PRIMITIVE_TRIANGLES' in script
assert 'mesh.surface_get_arrays' in script and 'mesh.get_surface_count()' in script
assert 'Mesh.ARRAY_VERTEX' in script and 'Mesh.ARRAY_NORMAL' in script
assert 'func _build_overlay(mesh: Mesh) -> ArrayMesh:' in script
assert 'func _position_key(' in script
assert 'normal_sum' in script and 'vertex_normals' in script
assert '_mesh_cache' in script and 'SCAN_INTERVAL' in script
assert 'MAX_TRIANGLES_PER_MESH' in script
assert 'source.add_child(instance)' in script
assert 'instance.material_override = _ink_material' in script

# No hinge angles, view-dependent front/back sign tests, or camera-space
# edge ribbons: even a 90-degree steep surface must NOT generate an ink line.
assert 'CREASE_DEGREES' not in script
assert '_extract_edges' not in script
assert 'crease_cosine' not in script
assert 'CUSTOM0' not in shader and 'edge_visible' not in shader
assert 'a_facing' not in shader and 'b_facing' not in shader
assert 'bool silhouette' not in shader
assert 'cull_front' in shader and 'cull_disabled' not in shader
assert 'MODELVIEW_MATRIX' in shader and 'PROJECTION_MATRIX' in shader
assert 'NORMAL' in shader and 'VIEWPORT_SIZE' in shader
assert 'POSITION = clip;' in shader
assert 'ALPHA = 1.0;' in shader

# Depth and transparent-pass ordering must not change. Always draw after
# armor; hidden rear hull fragments remain occluded by opaque 3D geometry.
assert 'shader_type spatial;' in shader
assert 'depth_draw_never' in shader and 'depth_test_disabled' not in shader
assert 'RENDER_POLICY: DEPTH_TESTED_EMISSIVE; depth_test=on' in shader
assert 'const RENDER_ORDER = preload("res://scripts/render_order_policy.gd")' in script
assert '_ink_material.render_priority = RENDER_ORDER.DEPTH_TESTED_EMISSIVE' in script
assert 'ALPHA = 1.0;' in shader

# Regression reported on Android customization with IRIS HEAD D:
# Backfaces of authored double-sided/partially open geometry must never paint
# whole dark patches over the source. Require opaque depth attachment and a
# four-direction neighborhood vote before accepting a 3px contour fragment.
assert 'hint_depth_texture' in shader
assert 'filter_nearest' in shader and 'repeat_disable' in shader
assert 'INV_PROJECTION_MATRIX' in shader
assert 'CURRENT_RENDERER == RENDERER_COMPATIBILITY' in shader
assert 'opaque_depth_at' in shader
assert 'source_depth' in shader and 'SCREEN_UV' in shader
assert 'fwidth(source_depth)' in shader
assert 'abs(opaque_center - source_depth) <= near_epsilon' in shader
assert 'discard;' in shader
assert 'opaque_depth_at(SCREEN_UV + vec2(radius_px, 0.0))' in shader
assert 'opaque_depth_at(SCREEN_UV - vec2(radius_px, 0.0))' in shader
assert 'opaque_depth_at(SCREEN_UV + vec2(0.0, radius_px))' in shader
assert 'opaque_depth_at(SCREEN_UV - vec2(0.0, radius_px))' in shader
assert 'if (!near_surface)' in shader
assert 'ALPHA = 1.0;' in shader

# Preserve full subtree FX exclusion and runtime stale-ink cleanup.
assert 'func _is_eligible(' in script and 'func _is_fx_node(' in script
assert 'var ancestor: Node = source' in script
assert 'ancestor = ancestor.get_parent()' in script
assert 'get_meta("sera_no_view_edges", false)' in script
assert 'source.get_active_material(surface)' in script
assert 'BaseMaterial3D.TRANSPARENCY_DISABLED' in script
assert 'func _remove_overlay(' in script and '_remove_overlay(source)' in script
trail = (root / "scripts/sword_trail.gd").read_text(encoding="utf-8")
thruster = (root / "scripts/back_thruster_fx.gd").read_text(encoding="utf-8")
assert 'effect_root.set_meta("sera_no_view_edges", true)' in trail
assert 'set_meta("sera_no_view_edges", true)' in thruster
assert 'py tools/sera_view_edges_self_check.py' in manifest
assert 'gd tools/sera_view_edges_runtime_check.gd' in manifest
print("SERA_VISIBLE_MESH_CONTOURS_STATIC_PASS")
