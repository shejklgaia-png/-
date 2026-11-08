#!/usr/bin/env python3
"""v135: static source and numerical opacity-profile regression for CUSTOMIZE glow."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
s = (root/"shaders/nexus_customize_radial_glow.gdshader").read_text(encoding="utf-8")
n = (root/"scripts/command_nexus.gd").read_text(encoding="utf-8")
p = (root/"project.godot").read_text(encoding="utf-8")
outline = (root/"scripts/nexus_selection_outline.gd").read_text(encoding="utf-8")

assert 'config/name="SERA v135 - Solid core radial backdrop"' in p
assert 'render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;' in s
assert 'uniform vec4 glow_color : source_color = vec4(0.35, 0.85, 0.98, 1.0);' in s
for setting in (
    'core_radius : hint_range(0.0, 1.0) = 0.24',
    'core_opacity : hint_range(0.0, 1.0) = 0.72',
    'outer_radius : hint_range(0.0, 1.5) = 0.95',
    'outer_opacity : hint_range(0.0, 1.0) = 0.30',
):
    assert setting in s
assert 'smoothstep(core_radius - 0.03, core_radius + 0.03, radius)' in s
assert 'smoothstep(core_radius, outer_radius, radius)' in s
assert 'outer = pow(max(outer, 0.0), 1.35);' in s
assert 'float alpha = max(core * core_opacity, outer * outer_opacity);' in s
assert 'ALPHA = glow_color.a * alpha;' in s

# Numerical sample of the GLSL response at the authored default parameters.
def smoothstep(low, high, x):
    t = min(1.0, max(0.0, (x-low)/(high-low)))
    return t*t*(3.0-2.0*t)

def alpha(r):
    core = 1.0 - smoothstep(0.24-0.03, 0.24+0.03, r)
    outer = (max(0.0, 1.0-smoothstep(0.24, 0.95, r)))**1.35
    return max(core * 0.72, outer * 0.30)

assert abs(alpha(0.00)-0.72) < 1e-7
assert abs(alpha(0.15)-0.72) < 1e-7
assert 0.2 < alpha(0.40) < 0.72
assert 0.0 < alpha(0.70) < alpha(0.40)
assert alpha(0.95) == 0.0
assert alpha(1.40) == 0.0

# The gradient quad remains behind SERA; all other facility outlines persist.
assert 'CUSTOMIZE_GLOW_SCREEN_WIDTH: float = 0.60' in n
assert 'CUSTOMIZE_GLOW_SCREEN_HEIGHT: float = 0.56' in n
assert 'CUSTOMIZE_GLOW_DEPTH_OFFSET: float = 1.80' in n
assert 'outline.set("hide_customize_preview_outline", true)' in n
assert 'outline.set("hide_customize_preview_outline", false)' in n
assert 'if hide_customize_preview_outline and name == "CUSTOMIZE":' in outline
assert '"DEPLOYMENT": {"eye": Vector3(6.20, 5.30, 5.00)' in n
print("v135 central solid-color opacity & smooth outer fade: STATIC PASS")
print("Godot shader compilation and Android visual quality: NOT TESTED")
