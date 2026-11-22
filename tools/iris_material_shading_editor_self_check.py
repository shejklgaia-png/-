#!/usr/bin/env python3
"""NEXUS H02 IRIS fullscreen-only material shading editor contract.

Independent UX requirements: 4 material rows, separate thresholds/bands,
cyan lens light toggle, one-shot material flash and clipboard handoff.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
read = lambda p: (root / p).read_text(encoding="utf-8")
widget = read("scripts/sera_part_preview_widget.gd")
ui = read("scripts/sera_iris_material_controls.gd")
shader = read("shaders/sera_iris_polygon_light.gdshader")
closed = read("shaders/sera_iris_polygon_light_closed.gdshader")
manifest = read("tools/sera_ci_manifest.txt")

assert "py tools/iris_material_shading_editor_self_check.py" in manifest
assert 'enable_nexus_iris_id_contour and current_blueprint == "H02"' in widget
assert "set_fullscreen_state(enabled: bool)" in widget
assert "_material_toggle.visible = enabled and _is_iris_preview()" in widget
assert "_material_panel.visible = enabled and _material_editor_open" in widget
assert "func _toggle_material_editor()" in widget
assert "func _copy_iris_material_settings()" in widget
assert "DisplayServer.clipboard_set(" in widget
assert 'SERA_IRIS_MATERIAL_SHADING_V1' in widget
for key in ("armor", "dark_mechanism", "lens", "emission"):
    assert f'"{key}"' in widget
for key in ('"steps"', '"threshold"', '"lens_lit"'):
    assert key in widget
assert "func _flash_iris_material(" in widget
assert "sin(" in widget and "flash_power" in widget
assert "set_shader_parameter(\"flash_material\"" in widget
assert "set_shader_parameter(\"flash_power\"" in widget
assert "_material_panel.button_at(" in widget
assert "pressed.emit()" in widget
assert "material_selected.connect(" in widget
assert "value_changed.connect(" in widget
assert "emission_toggled.connect(" in widget
assert "copy_requested.connect(" in widget
assert '["装甲", "暗色機構", "レンズ", "発光"]' in ui
assert "陰影段階" in ui and "しきい値" in ui
assert "水色 点灯" in ui
assert "全材質をコピー" in ui
for shader_text in (shader, closed):
    assert "uniform int armor_levels" in shader_text
    assert "uniform int dark_levels" in shader_text
    assert "uniform int lens_levels" in shader_text
    assert "uniform float armor_threshold" in shader_text
    assert "uniform float dark_threshold" in shader_text
    assert "uniform float lens_threshold" in shader_text
    assert "uniform bool lens_emissive" in shader_text
    assert "uniform int flash_material" in shader_text
    assert "uniform float flash_power" in shader_text
    assert "floor(shifted * float(levels))" in shader_text
    # Actual authored 16x16 texture: light grey 184/190/196,
    # dark mechanism 53/54/55 and 93/95/96, cyan 43/141/173.
    for rgb in ("184.0, 190.0, 196.0", "43.0, 141.0, 173.0"):
        assert rgb in shader_text
    assert "normalize(NORMAL)" in shader_text
    assert "dFdx" not in shader_text and "dFdy" not in shader_text
assert shader.replace("cull_disabled", "cull_front") == closed
print("NEXUS H02 IRIS material shading editor static contract PASS")
