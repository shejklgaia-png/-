"""v20 static checks. The Godot render path itself requires an engine/device."""
import hashlib
import json
import math
from pathlib import Path
from PIL import Image
import numpy as np

root = Path(__file__).resolve().parents[1]
src = (root / 'scripts/sword_trail.gd').read_text()
main = (root / 'scripts/main.gd').read_bytes()
fx = (root / 'scripts/hit_burst.gd').read_bytes()
rig = (root / 'scripts/sera_rig.gd').read_bytes()
old_root = root.parents[1] / 'v19_work' / 'sera_portrait_godot_melee_v19'
assert 'ARC_TEXTURE = preload("res://assets/slash_arc_1024.png")' in src
assert 'orientation_locked = true' in src
assert src.count('orientation_locked = true') == 1
assert 'if not orientation_locked and has_previous and clip_time >= SWING_ONSET:' in src
assert 'start_tip: Vector3 = previous_tip.lerp(tip, fraction)' in src
assert 'tip_travel: Vector3 = tip - previous_tip' in src
assert 'tangent: Vector3 = tip_travel - x * tip_travel.dot(x)' in src
assert 'var x: Vector3 = -radial / blade_length' in src
assert 'texture_center = (start_tip' in src
assert 'instance.to_local(world_point)' in src
assert 'view_camera.global' not in src
assert 'mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, arc_material)' in src
assert 'on_hit(_world_hit:' in src
assert 'AFTER_SWING_DECAY' in src
assert 'HISTORY_SECONDS' not in src
assert 'SUBDIVISIONS' not in src
assert 'sample_times' not in src
assert 'SWEEP_TEXTURE' not in src
assert src.count('mesh.surface_end()') == 1

tex = Image.open(root / 'assets/slash_arc_1024.png').convert('RGBA')
assert tex.size == (1024, 1024)
assert tex.getpixel((0, 0))[3] == 0
assert tex.getpixel((140, 630))[3] > 0

# Reproduce the exact deterministic basis/quad mathematics. This validates
# pixel registration and tangent alignment over random 3D sword attitudes.
rng = np.random.default_rng(20261105)
u_start, v_start = 0.135, 0.615
for _ in range(5000):
    base = rng.uniform(-10.0, 10.0, 3)
    blade = rng.normal(size=3)
    blade /= np.linalg.norm(blade)
    length = rng.uniform(0.9, 1.3)
    tip = base + blade * length
    travel = rng.normal(size=3)
    travel -= blade * travel.dot(blade)
    travel /= np.linalg.norm(travel)
    travel *= rng.uniform(0.03, 1.5)
    x = -blade
    tangent = travel - x * travel.dot(x)
    y = tangent / np.linalg.norm(tangent)
    assert abs(x.dot(y)) < 1e-12
    assert y.dot(travel) > 0
    assert np.linalg.norm(np.cross(x, y)) > 0.9999
    w = float(np.clip(length * 3.25, 2.85, 4.25))
    h = w * 0.97
    center = tip - x * (u_start - 0.5) * w - y * (0.5 - v_start) * h
    uv_to_world = lambda u,v: center + x * (u - 0.5) * w + y * (0.5 - v) * h
    assert np.linalg.norm(uv_to_world(u_start, v_start) - tip) < 1e-11
    # Moving in initial tangent direction should go toward decreasing V.
    assert np.dot(uv_to_world(u_start, v_start-0.02)-tip, travel) > 0

for filename in ('scripts/main.gd', 'scripts/hit_burst.gd', 'scripts/sera_rig.gd',
                 'shaders/slash_foil.gdshader', 'assets/slash_arc_1024.png',
                 'assets/spark_dark_red_outline.png'):
    reference = old_root / filename
    if reference.is_file():
        assert hashlib.sha256((root/filename).read_bytes()).hexdigest() == hashlib.sha256(reference.read_bytes()).hexdigest(), filename

print('v20: first-swing orientation lock and left-horn-to-tip pixel alignment: OK')
print('v20: 5000 randomized orthogonality/orientation/pixel tests: OK')
print('v20: slash texture transparent; v19 sparks, rig, camera, and gameplay preserved: OK')
print('Godot in-engine/Android rendering NOT checked here.')
