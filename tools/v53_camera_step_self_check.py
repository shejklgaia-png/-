#!/usr/bin/env python3
"""v53 static and numerical regression checks. Not a Godot runtime test."""
from pathlib import Path
import hashlib
import math
import random
import re

root = Path(__file__).resolve().parents[1]
main = (root / 'scripts/main.gd').read_text(encoding='utf-8')
rig = (root / 'scripts/sera_rig.gd').read_text(encoding='utf-8')
scene = (root / 'scenes/main.tscn').read_text(encoding='utf-8')
const = {k: float(v) for k, v in re.findall(r'^const (\w+): float = ([\d.]+)', main, re.M)}
expected = {
    'STEP_MIN_ARC_LENGTH': 2.0,
    'STEP_MAX_ARC_LENGTH': 4.0,
    'STEP_ORBIT_ANGLE_DEGREES': 35.0,
    'STEP_SPEED': 10.0,
    'STEP_CLOSE_SPEED': 6.0,
    'STEP_CLOSE_DISTANCE': 2.0,
    'STEP_MAX_DURATION': 0.4,
    'STEP_CLOSE_ORBIT_MAX_DEGREES': 120.0,
    'CAMERA_ELEVATION_RATIO': 0.1325,
    'CAMERA_FOCUS_DROP': 0.90,
    'CAMERA_CLOSE_RADIUS': 7.8,
    'CAMERA_BASE_RADIUS': 16.0,
    'SCREEN_MARGIN_BOTTOM': 0.75,
    'TARGET_FRAME_BOTTOM': 0.75,
}
for k, v in expected.items():
    assert const[k] == v, (k, const[k], v)
for needle in (
    'step_detail_label.text = "MIN 2.0m  /  MAX 0.4s"',
    'return STEP_CLOSE_SPEED if radius <= STEP_CLOSE_DISTANCE else STEP_SPEED',
    'step_speed_current = _step_speed_for_radius(radius)',
    'minf(STEP_MAX_ARC_LENGTH, step_speed_current * STEP_MAX_DURATION)',
    'var close_radius_limit: float = (STEP_MIN_ARC_LENGTH',
    'maxf(deg_to_rad(STEP_ORBIT_ANGLE_DEGREES), STEP_MIN_ARC_LENGTH / radius)',
    'step_duration_current = path_length / step_speed_current',
    'player.move_and_collide(remainder)',
    'player.move_and_slide()',
    'target.global_position - Vector3(0.0, CAMERA_FOCUS_DROP, 0.0)',
    'CAMERA_ELEVATION_RATIO * camera_radius',
    'projected.y > size.y * TARGET_FRAME_BOTTOM',
    'lower_screen.y <= size.y * SCREEN_MARGIN_BOTTOM',
    '_fit_full_frame()',
    'rig.call("start_side_step", side)',
    'rig.call("finish_side_step", resume_moving)',
    'func _classify_side_flick(displacement: Vector2, seconds: float) -> int:',
):
    assert needle in main, needle
assert 'Step_R' in rig and 'Step_L' in rig
assert 'SeraPrototype' in scene

# Compare to v52, if available, to verify no unrelated function or asset changes.
base = root.parent / 'sera_portrait_godot_melee_v52_lower_safe_camera'
if (base / 'scripts/main.gd').exists():
    old = (base / 'scripts/main.gd').read_text(encoding='utf-8')
    def funcs(src):
        return {m.group(1): m.group(0) for m in re.finditer(
            r'^func (\w+)\([^\n]*\)[\s\S]*?(?=^func |\Z)', src, re.M)}
    a, b = funcs(main), funcs(old)
    assert a.keys() == b.keys(), 'Unexpected functions added or removed'
    def runtime_only(s):
        return '\n'.join(l.rstrip() for l in s.splitlines()
                         if not l.lstrip().startswith('#'))
    for k in a:
        if k == '_refresh_step_status_ui':
            expect = b[k].replace('MIN 1.5m  /  MAX 0.4s', 'MIN 2.0m  /  MAX 0.4s')
            assert a[k] == expect, k
        else:
            assert runtime_only(a[k]) == runtime_only(b[k]), 'Unexpected function change: '+k
    for folder in ['assets', 'blockbench', 'scenes', 'shaders', 'scripts']:
        unchanged = lambda x: {
            str(p.relative_to(x)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in (x / folder).rglob('*') if p.is_file() and p.name != 'main.gd'
        }
        assert unchanged(root) == unchanged(base), 'Unrelated files changed: '+folder
    print('PASS: all other runtime functions and assets byte-preserved vs v52')

# Numerical mirror of the step planning code (without physical collisions).
def plan(radius):
    speed = 6.0 if radius <= 2.0 else 10.0
    length_cap = min(4.0, speed * 0.4)
    linear = radius < 2.0 / math.radians(120)
    if linear:
        length = 2.0
        angle = 0.0
    else:
        angle = min(max(math.radians(35), 2.0 / radius), length_cap / radius)
        length = radius * angle
    return speed, length, length / speed, angle, linear

random.seed(53)
radii = [0., .01, .1, .5, .9549, .955, 1., 1.4, 1.5, 1.999999,
         2.0, 2.000001, 2.5, 3., 4., 5., 6.55, 8., 12., 30., 100.]
radii += [random.random() * 80 for _ in range(1000)]
checks = 0
for r in radii:
    speed, distance, duration, angle, linear = plan(r)
    assert speed == (6.0 if r <= 2.0 else 10.0)
    assert 2.0-1e-9 <= distance <= 4.0+1e-9
    assert 0 < duration <= 0.4+1e-9
    assert math.isclose(distance / duration, speed, rel_tol=1e-9)
    if not linear:
        assert angle <= math.radians(120)+1e-9
        assert math.isclose(r*angle, distance, rel_tol=1e-9)
    for fps in (15, 24, 30, 60, 90, 120, 144):
        elapsed = 0.
        while elapsed < duration:
            elapsed = min(duration, elapsed + 1/fps)
        assert math.isclose(elapsed, duration, abs_tol=1e-10)
        checks += 1
assert math.isclose(plan(2)[2], 2/6, rel_tol=1e-9)
assert math.isclose(plan(3)[1], 2, rel_tol=1e-9)
assert math.isclose(plan(5)[1], 5*math.radians(35), rel_tol=1e-9)
assert math.isclose(plan(8)[1], 4, rel_tol=1e-9)
print(f'PASS: minimum planned path 2.0m, max 4.0m, 6/10m/s, <=0.40s ({checks} rate cases)')

# Independent pinhole projection sanity check with restored v51 tilt, v52 framing.
vertical = math.tan(math.radians(61/2))
horizontal = vertical * 720 / 1280

def project(world, radius, yaw):
    sin, cos = math.sin(yaw), math.cos(yaw)
    e = const['CAMERA_ELEVATION_RATIO']
    n = math.sqrt(1 + e*e)
    focus_y = 1.53 - const['CAMERA_FOCUS_DROP']
    cam = (radius*sin, focus_y + e*radius, radius*cos)
    v = tuple(world[i] - cam[i] for i in range(3))
    right = (cos, 0, -sin)
    up = (-e*sin/n, 1/n, -e*cos/n)
    forward = (-sin/n, -e/n, -cos/n)
    z = sum(v[i]*forward[i] for i in range(3))
    if z <= 0: return None
    x = sum(v[i]*right[i] for i in range(3))
    y = sum(v[i]*up[i] for i in range(3))
    return (0.5+x/(2*z*horizontal), 0.5-y/(2*z*vertical))

samples = 0
for d in [1.5, 2, 3, 5, 8, 12]:
    for yaw in [-.65, -.3, 0, .3, .65]:
        radius = max(7.8, d+2)
        corners = [(x, 1.53+y, z) for x in [-1,1] for y in [-1,1] for z in [-1,1]]
        points = corners + [(0, .08, d), (0, 1.85, d)]
        for attempt in range(50):
            coords = [project(pt, radius, yaw) for pt in points]
            good = (all(q is not None for q in coords)
                    and all(.025 <= q[0] <= .975 and .045 <= q[1] <= .75 for q in coords[:8])
                    and all(.02 <= q[0] <= .98 and .06 <= q[1] <= .75 for q in coords[8:]))
            if good: break
            radius *= 1.23
        assert good, (d, yaw, coords)
        samples += 1
print(f'PASS: v51 camera tilt + v52 focus/25% lower safe-space can fit ({samples} projection samples)')
print('NOTE: Mathematical/static only. Godot runtime and Android-device behavior not tested.')
