#!/usr/bin/env python3
"""SERA v122 front kiosk yaw verification; read-only static regression."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
src = (ROOT / "scripts/command_nexus.gd").read_text(encoding="utf-8")
project = (ROOT / "project.godot").read_text(encoding="utf-8")
import re
version = re.search(r'config/name="SERA v(\d+)', project)
assert version is not None and int(version.group(1)) >= 122
assert '_module("kiosk", Vector3(-1.85, 0.0, 0.25), deg_to_rad(28.0))' in src
assert '_module("kiosk", Vector3(1.85, 0.0, 0.25), deg_to_rad(-28.0))' in src
assert src.count('_module("kiosk"') == 2
assert 'cam.position = Vector3(0.0, 4.00, 8.65)' in src
assert 'cam.fov = 62.0' in src
assert 'rig.set_process(false)' in src
assert 'HeaderDivider' not in src
assert 'Button.new()' not in src
print("v123 mirrored front kiosk rotations (+28/-28 deg): PASS")
print("Godot and Android runtime not validated by this static test.")
