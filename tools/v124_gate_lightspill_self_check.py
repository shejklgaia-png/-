#!/usr/bin/env python3
"""SERA v124: static check of gate direction, light spill and console clearance.

Geometry is analysed with the same pinhole camera parameters, but Godot and
Android rendering/performance still require an actual device run.
"""
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
script = (ROOT / "scripts/command_nexus.gd").read_text(encoding="utf-8")
project = (ROOT / "project.godot").read_text(encoding="utf-8")
data = (ROOT / "assets/base_command_modules.gd").read_text(encoding="utf-8")
modules = json.loads(data.split("const MODULES = ", 1)[1].strip())

import re
version = re.search(r'config/name="SERA v(\\d+)', project)
assert version is not None and int(version.group(1)) >= 124
assert 'run/main_scene="res://scenes/launch_menu.tscn"' in project
assert 'pointing/emulate_mouse_from_touch=false' in project
assert 'renderer/rendering_method="gl_compatibility"' in project

# The gate's authored opening is local +Z. atan2(X, Z) must be negative
# for a right-hand gate facing the stage to its left/forward.
assert 'const GATE_ORIGIN: Vector3 = Vector3(4.00, 0.02, -10.48)' in script
assert 'const SERA_STAGE_ORIGIN: Vector3 = Vector3(0.0, 0.0, -4.75)' in script
assert 'return atan2(toward_sera.x, toward_sera.z)' in script
assert '_module("deployment_gate", GATE_ORIGIN, _gate_facing_yaw(), 1.20, 1.25)' in script
assert 'portal.position = GATE_ORIGIN' in script
assert 'portal.rotation.y = _gate_facing_yaw()' in script
yaw = math.degrees(math.atan2(-4.0, 5.73))
assert -40.0 < yaw < -30.0

# Two kiosk copies are closer to the camera but remain fully within 720px.
assert '_module("kiosk", Vector3(-1.95, 0.0, 1.30), deg_to_rad(36.0))' in script
assert '_module("kiosk", Vector3(1.95, 0.0, 1.30), deg_to_rad(-36.0))' in script
assert script.count('_module("kiosk"') == 2
assert 'cam.position = Vector3(0.0, 4.10, 10.20)' in script
assert 'cam.fov = 63.0' in script

# The gate effect uses only 4 meshes and one unshadowed point light; no particles,
# volumetric fog, overlay buttons or scene navigation are introduced.
for name in ("DeepBlueBacklight", "DiffusedAperture", "ThresholdGlow",
             "SpillOnFloor", "GateInteriorFill"):
    assert f'"{name}"' in script
assert 'light_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED' in script
assert 'light_material.emission_enabled = true' in script
assert 'light_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA' in script
assert 'lamp.shadow_enabled = false' in script
assert 'var lamp := OmniLight3D.new()' in script
assert script.count('OmniLight3D.new()') == 1
assert 'GPUParticles3D' not in script
assert 'CPUParticles3D' not in script
assert 'Button.new()' not in script

# Conservative projection bounding-box check against the unchanged HUD.
CAM = (0.0, 4.1, 10.2)
LOOK = (0.0, 3.0, -5.5)
FOV = math.radians(63.0)
def sub(a, b):
    return tuple(x-y for x, y in zip(a, b))
def dot(a, b):
    return sum(x*y for x, y in zip(a, b))
def norm(a):
    d = math.sqrt(dot(a, a))
    return tuple(x/d for x in a)
def cross(a, b):
    return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])

forward = norm(sub(LOOK, CAM))
right = norm((-forward[2], 0.0, forward[0]))
up = cross(right, forward)
factor = 1.0/math.tan(FOV/2.0)

def ry(v, a):
    return (math.cos(a)*v[0]+math.sin(a)*v[2], v[1],
            -math.sin(a)*v[0]+math.cos(a)*v[2])

def bbox(name, position, angle=0.0, scale=1.0, height_scale=1.0):
    points = []
    for part in modules[name]:
        lo = [x*.1 for x in part[1]]
        hi = [x*.1 for x in part[2]]
        center = [(a+b)/2 for a, b in zip(lo, hi)]
        dims = [b-a for a, b in zip(lo, hi)]
        for a in (-.5, .5):
            for b in (-.5, .5):
                for c in (-.5, .5):
                    offset = ry((a*dims[0], b*dims[1], c*dims[2]),
                                math.radians(part[4][1]))
                    local = [(center[i]+offset[i])*scale*
                             (height_scale if i==1 else 1.0) for i in range(3)]
                    turn = ry(local, angle)
                    point = tuple(position[i]+turn[i] for i in range(3))
                    v = sub(point, CAM)
                    depth = dot(v, forward)
                    assert depth > 0.1
                    px = 360*(1+dot(v, right)*factor/depth/(720/1280))
                    py = 640*(1-dot(v, up)*factor/depth)
                    points.append((px, py))
    return min(x for x,_ in points), min(y for _,y in points), max(x for x,_ in points), max(y for _,y in points)

screen = {
    "gate": bbox("deployment_gate", (4.00, 0.02, -10.48), math.radians(yaw), 1.20, 1.25),
    "left": bbox("kiosk", (-1.95, 0.0, 1.30), math.radians(36)),
    "right": bbox("kiosk", (1.95, 0.0, 1.30), math.radians(-36)),
}
tags = {
    "deployment": (0.666*720, 0.275*1280, (0.666+0.315)*720, 0.275*1280+67),
    "training": (0.018*720, 0.850*1280, (0.018+0.315)*720, 0.850*1280+67),
    "system": (0.666*720, 0.850*1280, (0.666+0.315)*720, 0.850*1280+67),
}
def overlap(a, b):
    return a[0] < b[2] and a[2] > b[0] and a[1] < b[3] and a[3] > b[1]

for name, rect in screen.items():
    assert rect[0] >= 0 and rect[2] <= 720, (name, rect)
    assert rect[1] >= 0 and rect[3] <= 1280, (name, rect)
    for tag, panel in tags.items():
        assert not overlap(rect, panel), (name, tag, rect)
assert screen["gate"][3] < screen["left"][1]
assert screen["gate"][3] < screen["right"][1]
print("v124 gate -> SERA facing, 4 light planes + 1 unshadowed lamp, 2 consoles and HUD clearance: PASS")
print("This is source / geometry verification only, not Godot/Android rendering.")
