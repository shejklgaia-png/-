#!/usr/bin/env python3
"""Explorable SERA base: non-invasive navigation and interaction contract."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

scene = read("scenes/base_exploration.tscn")
base = read("scripts/base_exploration.gd")
nexus = read("scripts/command_nexus.gd")
save = read("scripts/sera_save.gd")
project = read("project.godot")

assert 'res://scripts/base_exploration.gd' in scene
assert 'extends Node3D' in base
assert 'res://assets/base_command_modules.gd' in base
assert 'res://scripts/sera_rig.gd' in base
assert 'func _move_player(' in base
assert 'func _nearest_station(' in base
assert 'InputEventScreenTouch' in base and 'InputEventScreenDrag' in base
assert 'Control.MOUSE_FILTER_IGNORE' in base
assert 'change_scene_to_file(NEXUS_SCENE)' in base
assert 'SeraSave.requested_nexus_target' in base
for target in ('CUSTOMIZE', 'TRAINING', 'SYSTEM', 'DATA ARCHIVE', 'DEPLOYMENT'):
    assert '"focus": "' + target + '"' in base
assert 'const BASE_SCENE: String = "res://scenes/base_exploration.tscn"' in nexus
assert 'SeraSave.requested_nexus_target' in nexus
assert 'SeraSave.requested_nexus_target' in save
assert 'pointing/emulate_mouse_from_touch=false' in project
assert 'run/main_scene="res://scenes/bittaran_battle.tscn"' in project
print("SERA_BASE_EXPLORATION_STATIC_PASS")
