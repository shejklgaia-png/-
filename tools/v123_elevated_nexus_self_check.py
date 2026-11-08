#!/usr/bin/env python3
"""v123: Blockbench parity and approximate 720x1280 projected separation.

Static source/model test only; device rendering and Godot parsing not claimed.
"""
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
script = (ROOT / "scripts/command_nexus.gd").read_text(encoding="utf-8")
project = (ROOT / "project.godot").read_text(encoding="utf-8")
embedded = (ROOT / "assets/base_command_modules.gd").read_text(encoding="utf-8")
models = json.loads(embedded.split("const MODULES = ", 1)[1])

assert 'config/name="SERA v123 - Elevated Nexus Base"' in project
assert 'run/main_scene="res://scenes/launch_menu.tscn"' in project
assert 'renderer/rendering_method="gl_compatibility"' in project
assert 'pointing/emulate_mouse_from_touch=false' in project
assert "MultiMesh.TRANSFORM_3D" in script
assert "SeraRig.new()" in script
assert "rig.set_process(false)" in script
assert "Button.new()" not in script
assert "HeaderDivider" not in script

for name in ("archive_stairs", "gate_stage"):
    source = json.loads((ROOT / "blockbench/base" / f"SERA_{name}.bbmodel").read_text(encoding="utf-8"))
    from_source = [[e["name"], e["from"], e["to"], e["color"], e["rotation"]]
                   for e in source["elements"]]
    assert models[name] == from_source, f"Embedded mismatch: {name}"

assert '_module("archive_stairs", Vector3(-3.55, 0.0, -8.25))' in script
assert '_module("data_bank", Vector3(-3.55, 2.25, -8.25))' in script
assert '_module("gate_stage", Vector3(3.10, 0.0, -9.75), 0.0, 1.0, Vector3(0.70, 1.0, 1.0))' in script
assert '_module("deployment_gate", Vector3(3.10, 2.45, -9.75), 0.0, 1.40, Vector3(0.70, 1.0, 1.0))' in script
assert '_module("kiosk", Vector3(-1.85, 0.0, 0.25), deg_to_rad(28.0))' in script
assert '_module("kiosk", Vector3(1.85, 0.0, 0.25), deg_to_rad(-28.0))' in script
assert '_module("maintenance_pad", Vector3(0.0, 0.0, -4.80))' in script
assert '_module("maintenance_canopy", Vector3(0.0, 8.50, -5.20), 0.0, 0.96)' in script

assert 'cam.position = Vector3(0.0, 4.00, 8.65)' in script
assert 'cam.look_at(Vector3(0.0, 2.70, -5.15), Vector3.UP)' in script
assert 'cam.fov = 62.0' in script

# The raised deck top is 2.22m; the archive console starts at 2.25m.
deck = next(e for e in models["archive_stairs"] if e[0] == "Elevated archive deck")
assert abs(deck[2][1] * 0.1 - 2.22) < 0.0001
steps = [e for e in models["archive_stairs"] if e[0].startswith("Step riser")]
assert len(steps) == 6
assert max(e[2][1] * 0.1 for e in steps) > 2.0

# Gate is furthest back and is about three SERA-model-heights tall.
assert -9.75 < -8.25 < -4.80 < 0.25
gate_height = max(e[2][1] - e[1][1] for e in models["deployment_gate"]) * 0.1 * 1.4
assert gate_height >= 5.4  # Individual part height; overall arch ~6.1m
gate_extent = max(e[2][1] for e in models["deployment_gate"]) * 0.1 * 1.4
assert gate_extent > 6.0

# Conservative projection of every cuboid corner, yaw-only for auxiliary parts.
CAM = (0.0, 4.0, 8.65)
AIM = (0.0, 2.7, -5.15)
FOV = 62.0
ASPECT = 720.0 / 1280.0

def sub(a, b):
    return tuple(x-y for x, y in zip(a, b))

def dot(a, b):
    return sum(x*y for x, y in zip(a, b))

def norm(a):
    return tuple(x / math.sqrt(dot(a, a)) for x in a)

def cross(a, b):
    return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])

def yaw(v, a):
    return (v[0]*math.cos(a)+v[2]*math.sin(a), v[1],
            -v[0]*math.sin(a)+v[2]*math.cos(a))

forward = norm(sub(AIM, CAM))
right = norm(cross(forward, (0.0, 1.0, 0.0)))
up = cross(right, forward)
factor = 1.0 / math.tan(math.radians(FOV / 2))

def bbox(module, location, scene_scale=1.0, heading=0.0, width_scale=1.0):
    pts = []
    for _, lo_raw, hi_raw, _, orientation in models[module]:
        lo = [v * 0.1 for v in lo_raw]
        hi = [v * 0.1 for v in hi_raw]
        mid = [(a+b)*0.5 for a, b in zip(lo, hi)]
        dim = [b-a for a, b in zip(lo, hi)]
        for dx in (-0.5, 0.5):
            for dy in (-0.5, 0.5):
                for dz in (-0.5, 0.5):
                    local_offset = yaw((dx*dim[0], dy*dim[1], dz*dim[2]),
                                       math.radians(orientation[1]))
                    local = tuple((mid[i] + local_offset[i]) * scene_scale * (
                        width_scale if i == 0 else 1.0) for i in range(3))
                    oriented = yaw(local, heading)
                    world = tuple(location[i] + oriented[i] for i in range(3))
                    displacement = sub(world, CAM)
                    depth = dot(displacement, forward)
                    assert depth > 0.1, (module, world)
                    x = (1 + dot(displacement, right) * factor / depth / ASPECT) * 360
                    y = (1 - dot(displacement, up) * factor / depth) * 640
                    pts.append((x, y))
    return (min(x for x, _ in pts), min(y for _, y in pts),
            max(x for x, _ in pts), max(y for _, y in pts))

def overlaps(a, b):
    return a[0] < b[2] and a[2] > b[0] and a[1] < b[3] and a[3] > b[1]

panels = {
    "DATA ARCHIVE": (0.018, 0.31, 0.315),
    "DEPLOYMENT": (0.735, 0.125, 0.250),
    "TRAINING": (0.015, 0.875, 0.300),
    "SYSTEM": (0.685, 0.875, 0.300),
    "CUSTOMIZE": (0.352, 0.875, 0.296),
}
panel_rects = []
for name, (x, y, w) in panels.items():
    assert f'_tag("{name}", ' in script
    panel_rects.append((name, (x*720, y*1280, (x+w)*720, y*1280+67)))

visible_items = {
    "data_bank": bbox("data_bank", (-3.55, 2.25, -8.25)),
    "archive_stairs": bbox("archive_stairs", (-3.55, 0, -8.25)),
    "gate_stage": bbox("gate_stage", (3.10, 0, -9.75), width_scale=0.70),
    "deployment_gate": bbox("deployment_gate", (3.10, 2.45, -9.75), scene_scale=1.4, width_scale=0.70),
    "maintenance_canopy": bbox("maintenance_canopy", (0, 8.50, -5.20), scene_scale=0.96),
    "kiosk_left": bbox("kiosk", (-1.85, 0, 0.25), heading=math.radians(28)),
    "kiosk_right": bbox("kiosk", (1.85, 0, 0.25), heading=math.radians(-28)),
}
for name, box in visible_items.items():
    assert box[0] >= -10 and box[2] <= 730, (name, "horizontal crop", box)
    assert box[1] >= -10 and box[3] <= 1280, (name, "vertical crop", box)
    for tag_name, rect in panel_rects:
        assert not overlaps(box, rect), f"{name} overlaps HUD {tag_name}: {box} vs {rect}"

# The tall gate must not visually overlap the forecourt consoles or the overhead ring.
assert not overlaps(visible_items["deployment_gate"], visible_items["kiosk_left"])
assert not overlaps(visible_items["deployment_gate"], visible_items["kiosk_right"])
assert not overlaps(visible_items["deployment_gate"], visible_items["maintenance_canopy"])
assert visible_items["deployment_gate"][3] < visible_items["kiosk_right"][1]
print("v123 archive stairs, distant oversized gate, Blockbench parity and HUD separation: PASS")
print("Godot/Android rendering and input remain untested.")
