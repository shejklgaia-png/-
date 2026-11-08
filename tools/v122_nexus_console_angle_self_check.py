#!/usr/bin/env python3
"""SERA v122 front kiosk yaw verification; read-only static regression."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
src = (ROOT / "scripts/command_nexus.gd").read_text(encoding="utf-8")
project = (ROOT / "project.godot").read_text(encoding="utf-8")
assert 'config/name="SERA v122 - Nexus Console Angles"' in project
assert '_module("kiosk", Vector3(-1.70, 0.0, -0.65), deg_to_rad(18.0))' in src
assert '_module("kiosk", Vector3(1.70, 0.0, -0.65), deg_to_rad(-18.0))' in src
assert src.count('_module("kiosk"') == 2
assert 'cam.position = Vector3(0.0, 3.8, 7.40)' in src
assert 'cam.fov = 56.0' in src
assert 'rig.set_process(false)' in src
assert 'HeaderDivider' not in src
assert 'Button.new()' not in src
print("v122 mirrored front kiosk rotations (+18/-18 deg): PASS")
print("Godot and Android runtime not validated by this static test.")
