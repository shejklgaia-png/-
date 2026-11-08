#!/usr/bin/env python3
"""v135: static source and numerical opacity-profile regression for CUSTOMIZE glow."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
s = (root/"shaders/nexus_customize_radial_glow.gdshader").read_text(encoding="utf-8")
n = (root/"scripts/command_nexus.gd").read_text(encoding="utf-8")
p = (root/"project.godot").read_text(encoding="utf-8")
outline = (root/"scripts/nexus_selection_outline.gd").read_text(encoding="utf-8")

assert 'config/name="SERA v149"' in p
assert 'render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;' in s
assert 'uniform vec4 glow_color : source_color = vec4(0.35, 0.85, 0.98, 1.0);' in s
for setting in (
    'core_radius : hint_range(0.0, 1.0) = 0.34',
    'core_opacity : hint_range(0.0, 1.0) = 0.91',
    'falloff_power : hint_range(0.5, 3.0) = 1.15',
):
    assert setting in s
assert 'smoothstep(core_radius, 1.0, radius)' in s
assert 'ALPHA = glow_color.a * core_opacity * pow(max(soft_falloff, 0.0), falloff_power);' in s
assert 'float alpha = max(' not in s

def smoothstep(low, high, x):
    t = min(1.0, max(0.0, (x-low)/(high-low)))
    return t*t*(3.0-2.0*t)

def alpha(r):
    return 0.91 * max(1.0-smoothstep(0.34, 1.0, r), 0.0)**1.15

assert abs(alpha(0.00)-0.91) < 1e-7
assert abs(alpha(0.33)-0.91) < 1e-7
assert alpha(0.34) > alpha(0.35) > alpha(0.6) > alpha(0.9) > alpha(1.0)
assert alpha(1.0) == 0.0
assert abs(alpha(0.341)-alpha(0.34)) < 0.001

# The gradient quad remains behind SERA; all other facility outlines persist.
assert 'CUSTOMIZE_GLOW_SCREEN_WIDTH: float = 0.46' in n
assert 'CUSTOMIZE_GLOW_SCREEN_HEIGHT: float = 0.42' in n
assert 'CUSTOMIZE_GLOW_DEPTH_OFFSET: float = 1.80' in n
assert 'outline.set("hide_customize_preview_outline", true)' in n
assert 'outline.set("hide_customize_preview_outline", false)' in n
assert 'if hide_customize_preview_outline and name == "CUSTOMIZE":' in outline
assert '"DEPLOYMENT": {"eye": Vector3(6.20, 5.30, 5.00)' in n
print("v135 central solid-color opacity & smooth outer fade: STATIC PASS")
print("Godot shader compilation and Android visual quality: NOT TESTED")
