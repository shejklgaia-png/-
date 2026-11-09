#!/usr/bin/env python3
"""v136: analytic smoothness/coverage and torso alignment (static only)."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
shader = (root/"shaders/nexus_customize_radial_glow.gdshader").read_text(encoding="utf-8")
script = (root/"scripts/command_nexus.gd").read_text(encoding="utf-8")
project = (root/"project.godot").read_text(encoding="utf-8")
outline = (root/"scripts/nexus_selection_outline.gd").read_text(encoding="utf-8")

assert 'config/name="SERA v151"' in project
assert 'render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;' in shader
assert 'uniform vec4 glow_color : source_color = vec4(0.35, 0.85, 0.98, 1.0);' in shader
assert 'core_radius : hint_range(0.0, 1.0) = 0.34' in shader
assert 'core_opacity : hint_range(0.0, 1.0) = 0.91' in shader
assert 'falloff_power : hint_range(0.5, 3.0) = 1.15' in shader
assert '1.0 - smoothstep(core_radius, 1.0, radius)' in shader
assert 'max(core * core_opacity, outer * outer_opacity)' not in shader

def alpha(r):
    t = max(0.0, min(1.0, (r-0.34)/0.66))
    smooth = t*t*(3.0-2.0*t)
    return 0.91*(1.0-smooth)**1.15

assert abs(alpha(0.00)-0.91) < 1.e-7
assert abs(alpha(0.33)-0.91) < 1.e-7
assert abs(alpha(0.34)-alpha(0.341)) < 0.001
assert abs(alpha(0.999)-alpha(1.0)) < 0.001
assert all(alpha(i / 1000.0) >= alpha((i+1) / 1000.0) - 1e-12
           for i in range(1000))
assert alpha(1.0) == 0.0
assert 'CUSTOMIZE_GLOW_SCREEN_WIDTH: float = 0.46' in script
assert 'CUSTOMIZE_GLOW_SCREEN_HEIGHT: float = 0.42' in script
assert 0.46 * 720 >= 330 and 0.42 * 1280 >= 535
assert 'CUSTOMIZE_GLOW_DEPTH_OFFSET: float = 1.80' in script
assert 'var body_bones: Dictionary = sera_display_rig.get("bones")' in script
assert 'bone.name in ["Chest", "Torso", "Waist"]' in script
assert 'cam.unproject_position(bone.global_position)' in script
assert 'center = body_pixels / float(body_count)' in script
assert 'outline.set("hide_customize_preview_outline", true)' in script
assert 'outline.set("hide_customize_preview_outline", false)' in script
assert 'if hide_customize_preview_outline and name == "CUSTOMIZE":' in outline
assert '"DEPLOYMENT": {"eye": Vector3(6.20, 5.30, 5.00)' in script
print("v136 continuous 720x1280 halo profile and torso tracking: STATIC PASS")
print("Godot/Android rendering and touch: NOT TESTED")
