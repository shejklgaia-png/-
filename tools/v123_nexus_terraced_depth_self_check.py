#!/usr/bin/env python3
"""v123 Command Nexus depth/occlusion static validation. Godot/Android not executed."""
import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = (ROOT / "scripts/command_nexus.gd").read_text(encoding="utf-8")
PROJECT = (ROOT / "project.godot").read_text(encoding="utf-8")
EMBEDDED = (ROOT / "assets/base_command_modules.gd").read_text(encoding="utf-8")
MODULES = json.loads(EMBEDDED.split("const MODULES = ", 1)[1].strip())
assert 'config/name="SERA v123 - Nexus Terraced Depth"' in PROJECT
assert 'run/main_scene="res://scenes/launch_menu.tscn"' in PROJECT
assert 'pointing/emulate_mouse_from_touch=false' in PROJECT
assert "MultiMesh.TRANSFORM_3D" in SRC
assert "scaled_local(hi - lo)" in SRC
assert 'var stretch := Vector3(1.0, height_factor, 1.0)' in SRC
assert 'SeraRig.new()' in SRC and 'rig.set_process(false)' in SRC
assert "Button.new()" not in SRC and 'HeaderDivider' not in SRC

# All Godot module geometry is sourced exactly from editable Blockbench files.
assert len(MODULES) == 7
for name, parts in MODULES.items():
    path = ROOT / "blockbench" / "base" / f"SERA_{name}.bbmodel"
    data = json.loads(path.read_text(encoding="utf-8"))
    assert len(data["elements"]) == len(parts) and len(parts) > 10, name
    assert len({e["uuid"] for e in data["elements"]}) == len(parts)
    assert len(data["outliner"]) == len(parts)
    actual = [[e["name"], e["from"], e["to"], e["color"], e["rotation"]]
              for e in data["elements"]]
    assert actual == parts, f"Blockbench geometry differs from Godot: {name}"

# Physical rear-wall opening must be large enough to expose the scaled gate.
rear = MODULES["hangar_shell"]
assert not any(p[0] == "Rear wall" for p in rear)
assert all(p[0] not in ("Wall column 2.5", "Wall column 4.5",
                         "Wall column 6.8") for p in rear)
left = next(p for p in rear if p[0] == "Rear wall left of gate")
right = next(p for p in rear if p[0] == "Rear wall right jamb")
header = next(p for p in rear if p[0] == "Rear wall above gate")
assert left[2][0] / 10 <= 1.1
assert right[1][0] / 10 >= 7.2
assert header[1][1] / 10 >= 6.9

# Raised archive consists of rising stairs, a landing and visible handrails.
stairs = MODULES["archive_mezzanine"]
steps = sorted((p for p in stairs if p[0].startswith("Ascend stair ")),
               key=lambda e: int(e[0].split()[-1]))
assert len(steps) == 6
tops = [p[2][1] / 10 for p in steps]
assert all(b > a for a, b in zip(tops, tops[1:]))
landing = next(p for p in stairs if p[0] == "Deck upper armor")
assert landing[2][1] / 10 > tops[-1]
assert sum("rail" in p[0].lower() for p in stairs) >= 12

expected_modules = (
    '_module("kiosk", Vector3(-1.82, 0.0, 0.75), deg_to_rad(34.0))',
    '_module("kiosk", Vector3(1.82, 0.0, 0.75), deg_to_rad(-34.0))',
    '_module("maintenance_pad", Vector3(0.0, 0.0, -4.75))',
    '_module("archive_mezzanine", Vector3(-4.00, 0.0, -6.55))',
    '_module("data_bank", Vector3(-4.00, 2.19, -8.95))',
    '_module("deployment_gate", Vector3(4.05, 0.02, -10.48), 0.0, 1.20, 1.25)',
)
for source in expected_modules:
    assert source in SRC, source
assert SRC.count('_module("kiosk"') == 2
assert -10.48 < -8.95 < -4.75 < 0.75  # gate most distant
assert 4.43 * 1.20 * 1.25 > 6.0  # gate much taller than SERA

# Screen-space tags: front console labels are moved below far-off models.
tags = {
    "DATA ARCHIVE": (0.018, 0.325, 0.315),
    "DEPLOYMENT": (0.666, 0.275, 0.315),
    "TRAINING": (0.018, 0.850, 0.315),
    "SYSTEM": (0.666, 0.850, 0.315),
    "CUSTOMIZE": (0.305, 0.935, 0.39),
}
for title, (x, y, width) in tags.items():
    assert re.search(rf'_tag\("{title}", "[^"]+", {x}, {y}, {width}\)', SRC)
    assert y * 1280 + 67 < 1280
assert 'cam.position = Vector3(0.0, 4.10, 10.20)' in SRC
assert 'cam.look_at(Vector3(0.0, 3.00, -5.50), Vector3.UP)' in SRC
assert 'cam.fov = 63.0' in SRC
assert 'stand.position = Vector3(0.0, 0.40, -4.75)' in SRC
assert 'surface.position = Vector3(0.0, 0.33, -4.75)' in SRC

# Pinhole projection of model vertices, including each box's X/Y/Z rotation.
def rot_xyz(v, angles):
    a, b, c = [math.radians(float(n)) for n in angles]
    x, y, z = v
    y, z = y * math.cos(a) - z * math.sin(a), y * math.sin(a) + z * math.cos(a)
    x, z = x * math.cos(b) + z * math.sin(b), -x * math.sin(b) + z * math.cos(b)
    return (x * math.cos(c) - y * math.sin(c),
            x * math.sin(c) + y * math.cos(c), z)

def vertices(name, origin, yaw=0, scale=1.0, height_scale=1.0):
    out = []
    for p in MODULES[name]:
        lo = [v * 0.1 for v in p[1]]
        hi = [v * 0.1 for v in p[2]]
        mid = [(a + b) * 0.5 for a, b in zip(lo, hi)]
        dim = [b - a for a, b in zip(lo, hi)]
        for xx in (-0.5, 0.5):
            for yy in (-0.5, 0.5):
                for zz in (-0.5, 0.5):
                    offset = rot_xyz([xx * dim[0], yy * dim[1], zz * dim[2]], p[4])
                    v = [(mid[j] + offset[j]) * scale * (height_scale if j == 1 else 1)
                         for j in range(3)]
                    x, y, z = rot_xyz(v, [0, yaw, 0])
                    out.append((x + origin[0], y + origin[1], z + origin[2]))
    return out

def unit(v):
    n = math.sqrt(sum(a * a for a in v))
    return tuple(a / n for a in v)

def dot(a, b):
    return sum(x * y for x, y in zip(a, b))

camera = (0, 4.10, 10.20)
look = (0, 3.00, -5.50)
forward = unit([look[i] - camera[i] for i in range(3)])
right = unit((-forward[2], 0, forward[0]))
up = (forward[1] * right[2] - forward[2] * right[1],
      forward[2] * right[0] - forward[0] * right[2],
      forward[0] * right[1] - forward[1] * right[0])
factor = 1.0 / math.tan(math.radians(63.0 / 2))

def bounds(pts):
    projected = []
    for point in pts:
        delta = [p - c for p, c in zip(point, camera)]
        d = dot(delta, forward)
        assert d > 0
        x = (1 + dot(delta, right) * factor / (720 / 1280) / d) * 360
        y = (1 - dot(delta, up) * factor / d) * 640
        projected.append((x, y))
    return (min(p[0] for p in projected), min(p[1] for p in projected),
            max(p[0] for p in projected), max(p[1] for p in projected))

objects = {
    "archive": bounds(vertices("data_bank", (-4.00, 2.19, -8.95))),
    "stairs": bounds(vertices("archive_mezzanine", (-4.00, 0.0, -6.55))),
    "gate": bounds(vertices("deployment_gate", (4.05, .02, -10.48),
                            scale=1.20, height_scale=1.25)),
    "left_console": bounds(vertices("kiosk", (-1.82, 0.0, .75), yaw=34)),
    "right_console": bounds(vertices("kiosk", (1.82, 0.0, .75), yaw=-34)),
}
for name, (left, top, right_edge, bottom) in objects.items():
    assert left >= -8 and right_edge <= 720, f"{name} clipped horizontally: {left, right_edge}"
    assert top >= 0 and bottom <= 1280, f"{name} clipped vertically"
    if name in ("archive", "gate"):
        # Neither far model occupies the lower read-only front signplates.
        assert bottom < tags["TRAINING"][1] * 1280, f"{name} hidden by foreground labels"
        # Nor its own label at the top of the screen.
        assert top > (tags["DATA ARCHIVE"][1] if name == "archive"
                      else tags["DEPLOYMENT"][1]) * 1280 + 67
assert objects["gate"][0] > objects["archive"][2], "Rear gate overlaps archive in projection"
print(f"v123 Blockbench-to-Godot geometry, 7 modules, {sum(len(v) for v in MODULES.values())} pieces, stair/deck and portal visibility: PASS")
print("This is analytic screen-space projection, not Godot rendering or Android runtime.")
