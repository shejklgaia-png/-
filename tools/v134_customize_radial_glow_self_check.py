#!/usr/bin/env python3
"""v134 checks: 3D radial halo behind SERA with no preview outline (static)."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
n = (root/"scripts/command_nexus.gd").read_text(encoding="utf-8")
o = (root/"scripts/nexus_selection_outline.gd").read_text(encoding="utf-8")
p = (root/"project.godot").read_text(encoding="utf-8")
sh = (root/"shaders/nexus_customize_radial_glow.gdshader").read_text(encoding="utf-8")

assert 'config/name="SERA v143 - Straight transfer and instant glow off"' in p
assert 'CUSTOMIZE_GLOW_SHADER = preload("res://shaders/nexus_customize_radial_glow.gdshader")' in n
assert "func _create_customization_glow() -> void:" in n
assert "var quad := QuadMesh.new()" in n
assert "var material := ShaderMaterial.new()" in n
assert 'backdrop.name = "CustomizePortraitRadialBackdrop"' in n
assert "cam.add_child(backdrop)" in n
assert "backdrop.visible = false" in n
assert "CUSTOMIZE_GLOW_DEPTH_OFFSET: float = 1.80" in n
assert "-customize_preview_position.z + CUSTOMIZE_GLOW_DEPTH_OFFSET" in n
assert "material.set_shader_parameter(\"glow_color\", Color(0.35, 0.85, 0.98, 1.0))" in n
assert "func _update_customization_glow() -> void:" in n
assert "_customization_screen_bounds()" in n
assert 'hide_customize_preview_outline: bool = false' in o
assert 'if hide_customize_preview_outline and name == "CUSTOMIZE":' in o
assert 'outline.set("hide_customize_preview_outline", true)' in n
assert 'outline.set("hide_customize_preview_outline", false)' in n

show = n.split("func _show_customization_preview() -> void:",1)[1].split("func _restore_customization_preview()",1)[0]
assert show.index("_fit_customization_preview()") < show.index("_update_customization_glow()")
assert show.index("_update_customization_glow()") < show.index("customize_glow_quad.visible = true")
assert show.index("customize_glow_quad.visible = true") < show.index('outline.set("hide_customize_preview_outline", true)')
hide = n.split("func _restore_customization_preview() -> void:",1)[1].split("func _customization_screen_bounds()",1)[0]
assert "customize_glow_quad.visible = false" in hide
back = n.split("func _return_to_overview() -> void:",1)[1].split("func _overview_arrived()",1)[0]
arrived = n.split("func _overview_arrived() -> void:",1)[1].split("func _move_camera(",1)[0]
assert "_restore_customization_preview()" in back
assert 'outline.set("hide_customize_preview_outline", false)' not in back
assert 'outline.set("hide_customize_preview_outline", false)' in arrived
rotation = n.split("func _rotate_customization_preview(delta_x: float) -> void:",1)[1].split("func _update_projected_silhouettes()",1)[0]
assert "_constrain_customization_preview_to_safe_area()" not in rotation
assert "_update_customization_glow()" not in rotation
assert "_capture_sera_silhouette(sera_display_rig)" in rotation
assert "shader_type spatial;" in sh
assert "unshaded" in sh and "depth_draw_never" in sh
assert "uniform vec4 glow_color : source_color" in sh
assert "ALPHA =" in sh and "smoothstep(core_radius, 1.0, radius)" in sh
assert "uniform float core_radius" in sh and "uniform float core_opacity" in sh
assert "uniform float falloff_power" in sh
assert "max(core * core_opacity" not in sh
assert "0.35, 0.85, 0.98" in sh
assert "CAMERA_TRANSITION_SECONDS: float = 0.18" in n
assert '"DEPLOYMENT": {"eye": Vector3(6.20, 5.30, 5.00)' in n
assert 'const NEXUS_POSE_NAMES: Array[String]' in n
print("v134 shader, preview-only outline suppression and restore: STATIC PASS")
print("Godot parser / Xperia rendering / touch: NOT TESTED")
