#!/usr/bin/env python3
"""v138 CUSTOMIZE three-zone placement and touch/menu exclusion regression.

Static source and independent viewport arithmetic; not a Godot/Android render.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
s = (root/"scripts/command_nexus.gd").read_text(encoding="utf-8")
p = (root/"project.godot").read_text(encoding="utf-8")
shader = (root/"shaders/nexus_customize_radial_glow.gdshader").read_text(encoding="utf-8")
assert 'config/name="SERA v144 - Torso-anchored straight transfer"' in p
assert '"CUSTOMIZE": Vector2(0.035, 0.435)' in s
assert 'func _customize_square_menu_rect(view: Vector2) -> Rect2:' in s
assert 'var square_side: float = minf(view.x * placement.y, view.y * 0.28)' in s
assert 'view.y * 0.865 - square_side' in s
assert 'func _customize_tall_menu_rect(view: Vector2) -> Rect2:' in s
assert 'Vector2(view.x * 0.525, view.y * 0.135)' in s
assert 'Vector2(view.x * 0.440, view.y * 0.730)' in s
assert 'func _customize_model_area(view: Vector2) -> Rect2:' in s
assert 'Vector2(square.position.x, top)' in s
assert 'var bottom: float = minf(view.y * 0.615,' in s
assert 'focus_panel.position = square.position' in s
assert 'focus_panel.size = square.size' in s
assert 'customize_right_panel.position = tall.position' in s
assert 'customize_right_panel.size = tall.size' in s
assert 'customize_right_panel.name = "CustomizeTallRightMenu"' in s
assert 'customize_right_panel.visible = target_name == "CUSTOMIZE"' in s
assert 'customize_right_panel.visible = false' in s
assert '_keep_customization_clear()' not in s

fit = s.split("func _fit_customization_preview() -> void:", 1)[1].split(
    "func _constrain_customization_preview_to_safe_area()", 1)[0]
constrain = s.split("func _constrain_customization_preview_to_safe_area() -> void:",1)[1].split(
    "func _is_customization_drag_zone(",1)[0]
glow = s.split("func _capture_customization_glow_layout() -> void:",1)[1].split(
    "func _update_customization_glow()",1)[0]
rotate = s.split("func _rotate_customization_preview(",1)[1].split(
    "func _update_projected_silhouettes()",1)[0]
drag = s.split("func _is_customization_drag_zone(",1)[1].split(
    "func _rotate_customization_preview(",1)[0]
assert "var frame: Rect2 = _customize_model_area(size)" in fit
assert "var frame: Rect2 = _customize_model_area(size)" in constrain
assert "var model_area: Rect2 = _customize_model_area(viewport_size)" in glow
assert "model_area.position.y + 20.0, model_area.end.y - 20.0" in glow
assert "_update_customization_glow()" not in rotate
assert "_constrain_customization_preview_to_safe_area()" not in rotate
assert "customize_right_panel.position, customize_right_panel.size).has_point(pixel)" in drag
assert "Rect2(focus_panel.position, focus_panel.size).has_point(pixel)" in drag
assert "Rect2(back_panel.position, back_panel.size).has_point(pixel)" in drag
assert 'CUSTOMIZE_GLOW_SCREEN_WIDTH: float = 0.46' in s
assert 'CUSTOMIZE_GLOW_SCREEN_HEIGHT: float = 0.42' in s
assert "uniform vec3 cyber_blue : source_color" in shader
assert "uniform vec2 grid_cells" in shader
assert "grid_strength * grid_mask" in shader

def rects(width, height):
    left_x, left_width = .035*width, .435*width
    side = min(left_width, .28*height)
    square = (left_x, .865*height-side, side, side)
    tall = (.525*width, .135*height, .44*width, .73*height)
    top = .10*height
    bottom = min(.615*height, square[1]-max(12., .012*height))
    preview = (left_x, top, side, bottom-top)
    margin = max(16., width*.04)
    back = (width-margin-62, height-margin-62, 62, 62)
    return preview, square, tall, back

def overlap(a, b):
    return max(a[0],b[0]) < min(a[0]+a[2],b[0]+b[2]) and (
        max(a[1],b[1]) < min(a[1]+a[3],b[1]+b[3]))

for w,h in ((720,1280),(658,1168),(1080,1920),(720,720)):
    preview, square, tall, back = rects(w,h)
    assert abs(square[2]-square[3]) < 1.e-5
    assert tall[3] > 1.9*tall[2]
    assert not any((overlap(preview,square), overlap(preview,tall),
                    overlap(square,tall), overlap(square,back),
                    overlap(tall,back)))
    assert 0 <= preview[0] and 0 <= preview[1]
    assert tall[0]+tall[2] <= w
    assert square[1]+square[3] <= h

preview, square, tall, back = rects(720,1280)
assert abs(square[2]-313.2) < .1
assert abs(tall[2]-316.8) < .1
assert abs(tall[3]-934.4) < .1
assert preview[0] < 26 and preview[1] < 129
print("v138 three-zone preview, square/tall panels and touch exclusion: STATIC PASS")
print("Godot/Android render and touch: NOT TESTED")
