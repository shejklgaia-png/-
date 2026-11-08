#!/usr/bin/env python3
"""SERA v121 layout regression (static geometry projection; not a Godot run)."""

import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = (ROOT / "scripts/command_nexus.gd").read_text(encoding="utf-8")
PROJECT = (ROOT / "project.godot").read_text(encoding="utf-8")

version = re.search(r'config/name="SERA v(\d+)', PROJECT)
assert version is not None and int(version.group(1)) >= 121
assert 'run/main_scene="res://scenes/launch_menu.tscn"' in PROJECT
assert 'pointing/emulate_mouse_from_touch=false' in PROJECT

# Read-only signplates only: no header in the 3D base (startup picker is untouched).
assert 'SERA SYSTEM   /   COMMAND NEXUS' not in SCRIPT
assert 'HeaderDivider' not in SCRIPT
assert 'func _layout_hud() -> void:' in SCRIPT
assert 'var rule: ColorRect' not in SCRIPT
assert 'Button.new()' not in SCRIPT

TAGS = {
    "DATA ARCHIVE": (0.018, 0.310, 0.315),
    "DEPLOYMENT": (0.735, 0.125, 0.250),
    "TRAINING": (0.015, 0.875, 0.300),
    "SYSTEM": (0.685, 0.875, 0.300),
    "CUSTOMIZE": (0.352, 0.875, 0.296),
}
for title, (x, y, width) in TAGS.items():
    assert re.search(
        rf'_tag\("{title}", "[^"]+", {x}, {y}, {width}\)', SCRIPT
    ), f"Signplate position changed: {title}"
assert TAGS["DATA ARCHIVE"][1] < TAGS["TRAINING"][1] - 0.25
assert TAGS["DEPLOYMENT"][1] < TAGS["SYSTEM"][1] - 0.25
for x, y, w in TAGS.values():
    assert 0.0 <= x <= 1.0 and 0.0 <= y <= 1.0 and 0.0 < w and x + w <= 1.0

# Front kiosks, intermediate SERA/pad, and rear archive/gate form three depth planes.
FRONT_LEFT = (-1.85, 0.0, 0.25)
FRONT_RIGHT = (1.85, 0.0, 0.25)
PAD = (0.0, 0.0, -4.80)
REAR_ARCHIVE = (-3.55, 2.25, -8.25)
REAR_GATE = (3.10, 2.45, -9.75)
def placed_positions(module: str) -> list[tuple[float, float, float]]:
    matches = re.findall(
        rf'_module\("{re.escape(module)}", Vector3\(([^)]+)\)', SCRIPT
    )
    return [tuple(float(n.strip()) for n in match.split(",")) for match in matches]

for name, expected in [
    ("maintenance_pad", [PAD]),
    ("data_bank", [REAR_ARCHIVE]),
    ("deployment_gate", [REAR_GATE]),
    ("kiosk", [FRONT_LEFT, FRONT_RIGHT]),
]:
    actual = placed_positions(name)
    assert len(actual) == len(expected), f"Wrong placement count: {name}"
    for value in expected:
        assert any(all(math.isclose(a, b, abs_tol=0.001) for a, b in zip(pos, value))
                   for pos in actual), f"Wrong position for {name}: {value}"
assert REAR_ARCHIVE[2] < PAD[2] < FRONT_LEFT[2]
assert REAR_GATE[2] < PAD[2] < FRONT_RIGHT[2]
assert 'surface.position = Vector3(0.0, 0.33, -4.80)' in SCRIPT
assert 'stand.position = Vector3(0.0, 0.40, -4.80)' in SCRIPT

# Camera keeps a frontal composition, while front terminals project larger than rear units.
CAMERA = (0.0, 4.0, 8.65)
LOOK = (0.0, 2.70, -5.15)
FOV = 62.0
assert 'cam.position = Vector3(0.0, 4.00, 8.65)' in SCRIPT
assert 'cam.look_at(Vector3(0.0, 2.70, -5.15), Vector3.UP)' in SCRIPT
assert 'cam.fov = 62.0' in SCRIPT

near = CAMERA[2] - FRONT_LEFT[2]
mid = CAMERA[2] - PAD[2]
far = CAMERA[2] - REAR_ARCHIVE[2]
assert near < mid < far
assert far / near > 1.85, "Front/background perspective separation weakened"
assert abs(FRONT_LEFT[0] + FRONT_RIGHT[0]) < 1e-9
assert CAMERA[0] == 0.0

# Shared gameplay assets, model and touch controls must remain unchanged.
assert 'SeraRig.new()' in SCRIPT
assert 'rig.set_process(false)' in SCRIPT
assert 'res://assets/base_command_modules.gd' in SCRIPT
assert 'MultiMesh.TRANSFORM_3D' in SCRIPT
print("v121 static nexus perspective, read-only labels, camera and depth: PASS")
print("Exact frame composition and text placement still require Android runtime verification.")
