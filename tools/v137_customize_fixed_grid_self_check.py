#!/usr/bin/env python3
"""SERA v137 fixed-pivot rotation, stationary grid and whole-scene input.

Source-level regression only: Godot and Android rendering/touch require device checks.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
script = (root/"scripts/command_nexus.gd").read_text(encoding="utf-8")
shader = (root/"shaders/nexus_customize_radial_glow.gdshader").read_text(encoding="utf-8")
project = (root/"project.godot").read_text(encoding="utf-8")
assert 'config/name="SERA v143 - Straight transfer and instant glow off"' in project

def section(start, end):
    return script.split("func " + start, 1)[1].split("func " + end, 1)[0]

show = section("_show_customization_preview() -> void:", "_restore_customization_preview()")
rotate = section("_rotate_customization_preview(delta_x: float) -> void:", "_update_projected_silhouettes()")
capture = section("_capture_customization_glow_layout() -> void:", "_update_customization_glow()")
update = section("_update_customization_glow() -> void:", "_apply_customization_preview_transform()")
zone = section("_is_customization_drag_zone(pixel: Vector2) -> bool:", "_rotate_customization_preview(")
input_handler = section("_input(event: InputEvent) -> void:", "_tap_at(")

# The size and position of SERA are established once, before the user turns it.
assert show.index("_fit_customization_preview()") < show.index("_capture_customization_glow_layout()")
assert show.index("_capture_customization_glow_layout()") < show.index("_update_customization_glow()")
assert show.index("_update_customization_glow()") < show.index("customize_glow_quad.visible = true")
assert "customize_preview_yaw = wrapf(customize_preview_yaw - yaw_delta, -PI, PI)" in rotate
assert "_apply_customization_preview_transform()" in rotate
assert "_capture_sera_silhouette(sera_display_rig)" in rotate
assert "_constrain_customization_preview_to_safe_area()" not in rotate
assert "_update_customization_glow()" not in rotate
assert "customize_preview_scale =" not in rotate
assert "customize_preview_position" not in rotate

# Only the background's initial captured ratio is used; it never follows yaw.
assert "customize_glow_center_ratio = Vector2(" in capture
assert 'bone.name in ["Chest", "Torso", "Waist"]' in capture
assert 'sera_display_rig.find_child("Head_Mesh", true, false)' in capture
assert "head_half_pixels = (right - left) * 0.5" in capture
assert "customize_glow_grid_spacing_ratio = clampf(" in capture
assert "customize_glow_center_ratio.x" in update
assert "customize_glow_center_ratio.y" in update
assert "customize_glow_grid_spacing_ratio" in update
assert 'material.set_shader_parameter("grid_cells", Vector2(' in update
assert "_capture_customization_glow_layout()" not in update

# Every pixel in the Godot viewport is eligible except menu and Back.
assert "Rect2(Vector2.ZERO, hud.size).has_point(pixel)" in zone
assert "Rect2(focus_panel.position, focus_panel.size).has_point(pixel)" in zone
assert "customize_right_panel.position, customize_right_panel.size).has_point(pixel)" in zone
assert "Rect2(back_panel.position, back_panel.size).has_point(pixel)" in zone
assert "pixel.y >=" not in zone and "pixel.y <=" not in zone
assert "pixel.x >" not in zone and "pixel.x <" not in zone
assert "return true" in zone
assert input_handler.count("if _is_customization_drag_zone(event.position):") >= 3
assert "_tap_at(event.position)" in input_handler

# Cyber blue and grid are within the same smooth radial alpha, without textures.
assert 'uniform vec3 cyber_blue : source_color' in shader
assert 'uniform vec3 grid_color : source_color' in shader
assert 'uniform vec2 grid_cells' in shader
assert "fract(phase)" in shader
assert "fwidth(phase)" in shader
assert "grid_strength * grid_mask" in shader
assert 'ALPHA = glow_color.a * core_opacity * pow(max(soft_falloff, 0.0), falloff_power);' in shader
assert "1.0 - smoothstep(core_radius, 1.0, radius)" in shader
assert 'CUSTOMIZE_GLOW_SCREEN_WIDTH: float = 0.46' in script
assert 'CUSTOMIZE_GLOW_SCREEN_HEIGHT: float = 0.42' in script
assert "CUSTOMIZE_GLOW_DEPTH_OFFSET: float = 1.80" in script
assert 'outline.set("hide_customize_preview_outline", true)' in script
assert 'outline.set("hide_customize_preview_outline", false)' in script

# At 720x1280, an approximately 80px head creates ~40px grid cells.
cell_px = 80.0 * 0.5
cols = (720 * 0.70) / cell_px
rows = (1280 * 0.46) / cell_px
assert 12.0 < cols < 13.0 and 14.0 < rows < 15.0
print("v137 fixed rotation, nontracking radial grid and exclusion-only hit zones: STATIC PASS")
print("Godot runtime / Android touch and rendering: NOT TESTED")
