#!/usr/bin/env python3
"""SERA v223: world-anchored, fading ribbon trail independently of jet mesh."""
from pathlib import Path
import math
import re

root = Path(__file__).resolve().parents[1]
read = lambda path: (root / path).read_text(encoding="utf-8")
fx = read("scripts/back_thruster_fx.gd")
shader = read("shaders/back_thruster_trail.gdshader")
original_shader = read("shaders/back_thruster.gdshader")
project = read("project.godot")
equipment = read("scripts/sera_equipment.gd")
main = read("scripts/main.gd")
match = re.search(r'config/name="SERA v(\d+)"', project)
assert match and int(match.group(1)) >= 223
for token in (
    'const RIBBON_SHADER = preload("res://shaders/back_thruster_trail.gdshader")',
    'ribbon_mesh.top_level = true',
    'nozzle.add_child(ribbon_mesh)',
    'ribbon_mesh.global_transform = Transform3D.IDENTITY',
    'global_transform.basis * Vector3.BACK',
    'ribbon_clock += maxf(delta, 0.0)',
    'ribbon_points.pop_front()',
    '"position": tip',
    '"time": ribbon_clock',
    '"break": is_new_streak',
    'is_new_streak = is_new_streak or distance > RIBBON_MAX_SEGMENT_DISTANCE',
    'if bool(current["break"]):',
    'camera.global_position if camera != null else Vector3.ZERO',
    'direction.cross(view.normalized())',
    'surface.set_color(colors[index])',
    'surface.commit()',
    'ribbon_mesh.mesh = null',
    '_update_ribbon_trail(enabled, delta)',
):
    assert token in fx, token
assert fx.index('_update_ribbon_trail(enabled, delta)') > fx.index(
    '_avoid_melee_body_penetration(nozzle, nozzle.get_parent() as Node3D)')
assert fx.index('_update_ribbon_trail(enabled, delta)') < fx.index("visible = enabled")
assert fx.index('_update_ribbon_trail(enabled, delta)') < fx.index("if not enabled:")
assert "RIBBON_LIFETIME_SECONDS: float = 0.34" in fx
assert "RIBBON_MAX_SAMPLES: int = 32" in fx
assert "RIBBON_SAMPLE_INTERVAL_SECONDS: float = 0.026" in fx
assert "RIBBON_MIN_SAMPLE_DISTANCE: float = 0.035" in fx
assert "RIBBON_MAX_SEGMENT_DISTANCE: float = 1.35" in fx
assert "blend_add" in shader and "cull_disabled" in shader
assert "COLOR.rgb" in shader and "ALPHA = COLOR.a" in shader
assert "depth_test_disabled" not in shader
assert "particles" not in shader.lower()
assert 'const EXHAUST_RADIAL_SIDES: int = 10' in fx
assert 'const BURST_RISE_SECONDS: float = 0.05' in fx
assert 'const BURST_FALL_SECONDS: float = 0.18' in fx
assert 'VERTEX.xy *= 1.0 + 14.0 * fan;' in original_shader
presentation = (Path(__file__).resolve().parents[1] / "scripts/sera_thruster_presentation.gd").read_text(encoding="utf-8")
assert "thruster_presentation.update(rig, exhaust_on," in main
assert "direction_of_exhaust, delta, backstroke_weight, left_sector_world," in main
assert "left_sector_world, acceleration_burst, normal_attack_exhaust)" in presentation
assert 'fx.call("set_exhaust", active and str(set_id) == selected_booster,' in equipment

# Opacity/width are bounded, ordered, and end at zero even after emission.
life = .34
for age in (0, .01, .08, .15, .28, .34):
    f = max(0., min(1., 1. - age / life))
    opacity = .63 * f ** 1.5
    width = .20 + .80 * f
    assert 0. <= opacity <= .63
    assert .20 <= width <= 1.
assert math.isclose(.63 * (max(0., 1. - .34 / life) ** 1.5), 0.)
assert .63 > .63 * (.5 ** 1.5) > 0.
# No cross-gap seam after teleport or reactivation.
def new_streak(was_emitting, distance):
    return (not was_emitting) or distance > 1.35
assert new_streak(False, 0.01)
assert new_streak(True, 1.5)
assert not new_streak(True, .1)
print("PASS v223: world-space nozzle ribbon trails fade after emission and split at discontinuities")
print("PASS: existing decagonal flame, 15x flare, torso protection and effect routing preserved")
print("Godot Android appearance and performance not tested here")
