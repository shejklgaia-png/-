#!/usr/bin/env python3
"""v132 static checks: enlarged front-facing preview and visible gate camera.

Godot/Android rendering and touch input remain untested.
"""
import json
import math
from pathlib import Path

root = Path(__file__).resolve().parents[1]
script = (root / "scripts/command_nexus.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
modules = json.loads((root / "assets/base_command_modules.gd").read_text(
    encoding="utf-8").split("const MODULES = ", 1)[1].strip())

assert 'config/name="SERA v135 - Solid core radial backdrop"' in project
assert '"DEPLOYMENT": {"eye": Vector3(6.20, 5.30, 5.00)' in script
assert '"look": Vector3(1.80, 3.40, -10.48), "fov": 76.0' in script
assert "const CUSTOMIZE_PREVIEW_TARGET_WIDTH_RATIO: float = 0.390" in script
assert "target_width / rect.size.x" in script
assert "func _constrain_customization_preview_to_safe_area() -> void:" in script
assert "customize_preview_scale = customize_preview_fitted_scale" in script
assert "_constrain_customization_preview_to_safe_area()" in script
assert "CUSTOMIZE_PREVIEW_ROTATION_SAMPLES: int = 16" in script
assert "InputEventScreenDrag" in script
assert "InputEventMouseMotion" in script
assert "NEXUS_POSE_NAMES" in script
assert "sera_display_rig.transform = sera_original_transform" in script
assert "get_tree().change_scene_to_file(TRAINING_SCENE)" in script
assert 'PANEL_LAYOUTS["CUSTOMIZE"]' in script
assert "size.x * (placement.x + placement.y) + 18.0" in script

# The selected camera must be inside the authored right-side wall.
wall = next(p for p in modules["hangar_shell"] if p[0] == "Right wall")
eye = (6.20, 5.30, 5.00)
look = (1.80, 3.40, -10.48)
assert eye[0] < wall[1][0] * 0.1
assert wall[1][2] * 0.1 < eye[2] < wall[2][2] * 0.1

def sub(a, b):
    return tuple(x-y for x, y in zip(a, b))

def dot(a, b):
    return sum(x*y for x, y in zip(a, b))

def norm(a):
    length = math.sqrt(dot(a, a))
    return tuple(x/length for x in a)

def cross(a, b):
    return (a[1]*b[2] - a[2]*b[1],
            a[2]*b[0] - a[0]*b[2],
            a[0]*b[1] - a[1]*b[0])

# Actual authored gate cuboid corners, with the game's yaw/scale/height.
yaw = math.atan2(-4.0, 5.73)
corners = []
for part in modules["deployment_gate"]:
    lo = [v * .1 * 1.2 for v in part[1]]
    hi = [v * .1 * 1.2 for v in part[2]]
    for ix in (0, 1):
        for iy in (0, 1):
            for iz in (0, 1):
                x = lo[0] if ix == 0 else hi[0]
                y = (lo[1] if iy == 0 else hi[1]) * 1.25
                z = lo[2] if iz == 0 else hi[2]
                corners.append((4.0 + math.cos(yaw)*x + math.sin(yaw)*z,
                                0.02 + y,
                                -10.48 - math.sin(yaw)*x + math.cos(yaw)*z))
forward = norm(sub(look, eye))
right = norm(cross(forward, (0, 1, 0)))
up = norm(cross(right, forward))
tan_half = math.tan(math.radians(76.0 / 2.0))
xs, ys = [], []
for vertex in corners:
    v = sub(vertex, eye)
    depth = dot(v, forward)
    assert depth > .05
    xs.append(.5 + dot(v, right) / (2 * depth * tan_half * (720/1280)))
    ys.append(.5 - dot(v, up) / (2 * depth * tan_half))
panel_right = .045 + .465
assert .42 < min(xs) < panel_right, (min(xs), panel_right)
assert panel_right - min(xs) >= .012, (min(xs), panel_right)
assert max(xs) <= .97 and min(ys) > .1 and max(ys) < .90
print("v132: gate camera inside hangar, projected gate beside menu: PASS")
print("v132: enlarged front preview, rotation containment and prior navigation: STATIC PASS")
print("Godot parser, Android rendering and gestures: NOT TESTED")
