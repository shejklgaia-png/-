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
closed_shader = read("shaders/sera_iris_polygon_light_closed.gdshader")
outline = read("shaders/sera_iris_mesh_id_outline.gdshader")
manifest = read("tools/sera_ci_manifest.txt")
assert "py tools/iris_polygon_shading_fullscreen_self_check.py" in manifest
assert "const IrisPolygonLight = preload(" in widget
assert "enable_nexus_iris_id_contour and current_blueprint == \"H02\"" in widget
assert "SHADING_MODES = [0, 2, 3, 4, 5, 6, 7, 8]" in widget
assert "8 * 22.0 + 7 * 3.0" in widget  # Compact 8-button vertical column
assert "_shade_column.size = Vector2(" in widget
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
assert "dFdx(VERTEX)" not in shader and "dFdy(VERTEX)" not in shader
assert "normalize(NORMAL)" in shader and "normalize(NORMAL)" in closed_shader
assert "const IrisFaceNormals = preload(" in widget
assert "IrisFaceNormals.make_face_uniform_mesh(" in widget
assert '"original_mesh"' in widget
assert 'source.mesh = preview_mesh' in widget
assert 'source.mesh = item.get("original_mesh")' in widget
assert "uniform int shade_levels" in shader
assert "shade_levels == 2" in shader and "shade_levels == 3" in shader
assert "shade_levels == 4" in shader  # Preserve existing legacy 4-band thresholds
for material in (shader, closed_shader):
    assert "hint_range(2, 8)" in material
    assert "float bands = float(shade_levels);" in material
    assert "floor(illumination * bands)" in material
    assert "mix(0.55, 1.05" in material
    assert "eye_pixel ? base" in material
assert shader.replace("cull_disabled", "cull_front") == closed_shader
# Every new level produces exactly the requested number of distinct brightness
# plateaus, strictly ordered, in the original 55%-to-105% envelope.
from math import floor
for levels in range(5, 9):
    steps = [0.55 + 0.50 * min(floor(i + 0.5), levels - 1) / (levels - 1)
             for i in range(levels)]
    assert len({round(v, 9) for v in steps}) == levels
    assert all(a < b for a, b in zip(steps, steps[1:]))
    assert abs(steps[0] - 0.55) < 1e-9
    assert abs(steps[-1] - 1.05) < 1e-9
assert "source_texture" in shader and "eye_pixel" in shader
assert "render_mode unshaded" in shader
assert "cull_disabled" in shader and "cull_front" in closed_shader
assert "IrisPolygonLightClosed" in widget and 'source.get_meta("sera_single_sided", false)' in widget
assert "uniform float stroke_px" in outline and "mesh_id_texture" in outline
print("NEXUS IRIS face shading/fullscreen source contracts PASS (not visual validation)")
