#!/usr/bin/env python3
"""NEXUS IRIS shaded face-mode/fullscreen integration contract (static).
Rendering and touch latency still require Godot/Android visual validation.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
read = lambda path: (root / path).read_text(encoding="utf-8")
widget = read("scripts/sera_part_preview_widget.gd")
nexus = read("scripts/command_nexus.gd")
shader = read("shaders/sera_iris_polygon_light.gdshader")
outline = read("shaders/sera_iris_mesh_id_outline.gdshader")
manifest = read("tools/sera_ci_manifest.txt")
assert "py tools/iris_polygon_shading_fullscreen_self_check.py" in manifest
assert "const IrisPolygonLight = preload(" in widget
assert "enable_nexus_iris_id_contour and current_blueprint == \"H02\"" in widget
assert "SHADING_MODES = [0, 2, 3, 4]" in widget
assert "func set_shading_mode(" in widget
assert "func _restore_original_materials(" in widget
assert "original_material_override" in widget
assert "func _apply_iris_shading(" in widget
assert "source.get_active_material(0)" in widget
assert "material_override = light_material" in widget
assert "source_texture" in widget
assert "func feed_touch(" in widget and "func feed_drag(" in widget
assert "double_tap_window_msec" in widget and "preview_fullscreen_requested.emit(" in widget
assert "IrisShadeModeColumn" in widget and "IrisFullscreenClose" in widget
assert "func _set_single_part_preview_fullscreen(" in nexus
assert "customize_single_part_preview.reparent(" in nexus
assert "func _route_fullscreen_preview_input(" in nexus
assert "_set_single_part_preview_fullscreen(false)" in nexus
assert "customize_single_part_preview.get_global_rect()" in nexus
assert "shader_type spatial;" in shader
assert "dFdx(VERTEX)" in shader and "dFdy(VERTEX)" in shader
assert "uniform int shade_levels" in shader
assert "shade_levels == 2" in shader and "shade_levels == 3" in shader
assert "source_texture" in shader and "eye_pixel" in shader
assert "render_mode unshaded" in shader
assert "uniform float stroke_px" in outline and "mesh_id_texture" in outline
print("NEXUS IRIS face shading/fullscreen source contracts PASS (not visual validation)")
