#!/usr/bin/env python3
"""v232: prevent outward left/right BOOST frame-edge yaw/zoom oscillation."""
from pathlib import Path
from math import sin, cos, sqrt, tan, radians, pi, isclose
import random
import re

ROOT = Path(__file__).resolve().parents[1]
def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

main = read("scripts/main.gd")
version = re.search(r'config/name="SERA v(\d+)"', read("project.godot"))
assert version and int(version.group(1)) >= 232
render = main.split("func _process(delta: float) -> void:", 1)[1].split(
    "func _close_step_target_relative_yaw", 1)[0]
assert 'var boost_edge_frame_guard: bool = (' in render
assert 'movement_boost_active or boost_pose_grace_remaining > 0.0' in render
assert 'gesture_active and not protect_close_step' in render
assert 'and combat_state == CombatState.IDLE and not step_active' in render
assert render.count('if not close_boost_camera_active and not boost_edge_frame_guard:') == 2
assert render.count('_enforce_screen_edge(bearing, delta)') == 2
assert '    if boost_edge_frame_guard:\n' in render
assert '        _fit_boost_frame_analytically(delta)' in render
assert '    else:\n        _fit_full_frame()\n        _relax_camera_fit_radius(delta)' in render
assert render.count('_fit_boost_frame_analytically(delta)') == 1
assert 'camera_yaw = lerp_angle(camera_yaw, bearing, easing * CAMERA_MOVING_YAW_SCALE)' in render

# BOOST-only exact perspective fit, no per-frame bisection or repeated unprojection.
fit = main.split("func _camera_radius_for_safe_point(", 1)[1].split(
    "func _fit_full_frame() -> void:", 1)[0]
for token in (
    'var horizontal_depth: float = absf(screen_x) / maxf(',
    'tan_h * (1.0 - 2.0 * margin_x)',
    'tan_v * (1.0 - 2.0 * margin_top)',
    'tan_v * (2.0 * margin_bottom - 1.0)',
    '(depth + offset.dot(outward)) / radial_scale',
    'camera.keep_aspect == Camera3D.KEEP_WIDTH',
    'camera_player_render_position',
    'camera_target_render_position',
    'for lateral in [-CAMERA_SAFE_CORE_HALF_WIDTH, 0.0, CAMERA_SAFE_CORE_HALF_WIDTH]:',
    'for height in [CAMERA_HEAD_HEIGHT, 0.08]:',
    'for dx in [-TARGET_HALF_SIZE, TARGET_HALF_SIZE]:',
    'for dy in [-TARGET_HALF_SIZE, TARGET_HALF_SIZE]:',
    'for dz in [-TARGET_HALF_SIZE, TARGET_HALF_SIZE]:',
    'var safe_radius: float = (_minimum_boost_camera_radius()',
    'camera_fit_radius_floor = move_toward(camera_fit_radius_floor,',
    'safe_radius, _camera_fit_release_speed() * maxf(delta, 0.0))',
    'camera_radius = maxf(camera_follow_radius, camera_fit_radius_floor)',
):
    assert token in fit, token
assert '_horizontal_safe(' not in fit
assert '_full_frame_safe(' not in fit
assert '_place_camera()' in fit
assert 'const CAMERA_FIT_RADIUS_RESERVE: float = 0.12' in main
assert 'const CAMERA_FIT_RELAX_SPEED: float = 1.25' in main
assert 'const CAMERA_CLOSE_BOOST_ENTER_DISTANCE: float = 6.0' in main
assert 'const BOOST_POSE_GRACE_SECONDS: float = 0.50' in main

# Independent projection audit of the derivation used at each protected point.
def dot(a,b):
    return sum(x*y for x,y in zip(a,b))
def sub(a,b):
    return tuple(x-y for x,y in zip(a,b))
def add(a,b):
    return tuple(x+y for x,y in zip(a,b))
def mul(a,s):
    return tuple(x*s for x in a)
def minimum_radius(points, focus, right, up, outward, radial_scale, tan_h, tan_v):
    minimum = 0.0
    for point, margin_x, margin_top, margin_bottom in points:
        offset = sub(point,focus)
        sx=dot(offset,right); sy=dot(offset,up)
        required_h = abs(sx)/(tan_h*(1-2*margin_x))
        required_v = (sy/(tan_v*(1-2*margin_top)) if sy >= 0
                      else -sy/(tan_v*(2*margin_bottom-1)))
        needed_depth = max(0.085, required_h, required_v)
        radius = max(0.0,(needed_depth + dot(offset,outward))/radial_scale)
        minimum = max(minimum, radius)
    return minimum
def all_points(player, target, right):
    points=[]
    torso=add(player,(0,1.05,0))
    for side in [-0.38,0,.38]:
        points.append((add(torso,mul(right,side)),.02,0.0,1.0))
    for y in [1.85,.08]:
        points.append((add(player,(0,y,0)),0.0,.145,.75))
    for dx in [-1.0,1.0]:
        for dy in [-1.0,1.0]:
            for dz in [-1.0,1.0]:
                points.append((add(target,(dx,dy,dz)),.025,.145,.75))
    return points

rng=random.Random(232)
tan_v=tan(radians(61)/2)
tan_h=tan_v*(720/1280)
for i in range(350):
    yaw=rng.uniform(-pi,pi)
    elevation=.21
    radial_scale=sqrt(1+elevation*elevation)
    outward=(sin(yaw)/radial_scale,elevation/radial_scale,cos(yaw)/radial_scale)
    right=(cos(yaw),0,-sin(yaw))
    up=(-sin(yaw)*elevation/radial_scale,1/radial_scale,
        -cos(yaw)*elevation/radial_scale)
    target=(rng.uniform(-5,5),1.53+rng.uniform(-.07,.07),rng.uniform(-13,-3))
    focus=add(target,(0,-1.35,0))
    # Both screen edges and close/far BOOST separations.
    player=(target[0]+rng.uniform(-45,45),0,target[2]+rng.uniform(-36,36))
    points=all_points(player,target,right)
    r=minimum_radius(points,focus,right,up,outward,radial_scale,tan_h,tan_v)+.12
    for point,mx,mt,mb in points:
        off=sub(point,focus)
        depth = r*radial_scale-dot(off,outward)
        assert depth > .08, (i,depth)
        sx=.5+dot(off,right)/(2*tan_h*depth)
        sy=.5-dot(off,up)/(2*tan_v*depth)
        # Independent projection should keep all 13 protected points inside.
        assert mx-1e-9 <= sx <= 1-mx+1e-9, (i,sx,mx)
        assert mt-1e-9 <= sy <= mb+1e-9, (i,sy,mt,mb)

# BOOST frame guard converges monotonically instead of subtracting 1.25m/s
# from an exact minimum and having to snap back next frame.
floor=0.0
needed=20.0
samples=[]
for _ in range(180):
    if floor < needed:
        floor=needed
    else:
        floor=max(needed, floor-1.25/118)
    samples.append(floor)
assert all(isclose(n,needed,abs_tol=1e-9) for n in samples)
# Releasing zoom remains bounded when distance decreases.
needed=11.0
for _ in range(118):
    prior=floor
    floor=max(needed, floor-1.25/118)
    assert 0 <= prior-floor <= 1.25/118+1e-9
assert 11.0 <= floor < 20.0

print("PASS v232: both edge BOOST guards, noniterative perspective framing,")
print("350 randomized left/right near/far viewport audits, stable zoom floor")
