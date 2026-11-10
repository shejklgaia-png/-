#!/usr/bin/env python3
"""SERA v233: verify only the closest follow-camera radius changes."""
from pathlib import Path
import math
import re

ROOT = Path(__file__).resolve().parents[1]
def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

main = read("scripts/main.gd")
project = read("project.godot")
version = re.search(r'config/name="SERA v(\d+)"', project)
assert version and int(version.group(1)) >= 233
def const(name):
    m = re.search(r'^const '+name+r': float = ([0-9.]+)', main, re.M)
    assert m is not None, name
    return float(m.group(1))

assert const("CAMERA_CLOSE_RADIUS") == 8.8
assert const("CAMERA_BASE_RADIUS") == 16.0
assert const("CAMERA_CLOSE_RANGE") == 1.5
assert const("CAMERA_FAR_RANGE") == 12.0
assert const("CAMERA_FOLLOW_RATE") == 1.65
assert const("CAMERA_FIT_RADIUS_RESERVE") == 0.12
assert const("CAMERA_FIT_RELAX_SPEED") == 1.25
assert const("CAMERA_CLOSE_BOOST_ENTER_DISTANCE") == 6.0
assert const("CAMERA_CLOSE_BOOST_EXIT_DISTANCE") == 7.5

render = main.split("func _process(delta: float) -> void:", 1)[1].split("func _close_step_target_relative_yaw", 1)[0]
assert 'var preferred_radius: float = lerpf(CAMERA_CLOSE_RADIUS, CAMERA_BASE_RADIUS, zoom_ratio)' in render
assert 'preferred_radius = maxf(preferred_radius, separation + 2.0)' in render
assert 'zoom_ratio = zoom_ratio * zoom_ratio * (3.0 - 2.0 * zoom_ratio)' in render
assert '_advance_camera_dolly(separation, preferred_radius, easing, delta)' in render
assert 'var legacy_radius: float = lerpf(' in main
assert 'camera_radius = maxf(camera_follow_radius, camera_fit_radius_floor)' in render
assert '_fit_boost_frame_analytically(delta)' in render
assert '_fit_full_frame()' in render

# Verify the preferred zoom follows the preexisting smoothstep envelope,
# with a single wider close endpoint. The frame-fit guard can still widen it.
def preferred(separation):
    x = max(0.0, min(1.0, (separation-1.5)/(12.0-1.5)))
    smooth = x*x*(3.0-2.0*x)
    r = 8.8+(16.0-8.8)*smooth
    return max(r,separation+2.0)

assert math.isclose(preferred(1.5),8.8)
assert math.isclose(preferred(0.0),8.8)
assert math.isclose(preferred(12.0),16.0)
assert all(preferred(d2)>=preferred(d1) for d1,d2 in zip(
    [i*0.1 for i in range(119)], [i*0.1 for i in range(1,120)]))
for x in [0.0,0.2,0.5,0.8,1.0]:
    old=7.8+(16.0-7.8)*(x*x*(3.0-2.0*x))
    new=8.8+(16.0-8.8)*(x*x*(3.0-2.0*x))
    assert new>=old-1e-10
assert 'const CAMERA_EDGE_MAX_CORRECTION_DEGREES_PER_SECOND: float = 240.0' in main
assert 'var boost_edge_frame_guard: bool = (' in render
assert 'var close_boost_camera_active: bool = false' in main
print("PASS v233: closest camera 7.8 -> 8.8m; follow/zoom/BOOST safety unchanged")
