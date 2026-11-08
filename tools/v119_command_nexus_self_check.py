#!/usr/bin/env python3
"""v119 Command Nexus startup: static regression checks (not an Android run)."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
project = (ROOT / "project.godot").read_text(encoding="utf-8")
menu_scene = (ROOT / "scenes/launch_menu.tscn").read_text(encoding="utf-8")
menu_script = (ROOT / "scripts/launch_menu.gd").read_text(encoding="utf-8")
base_scene = (ROOT / "scenes/command_nexus.tscn").read_text(encoding="utf-8")
base_script = (ROOT / "scripts/command_nexus.gd").read_text(encoding="utf-8")
training_scene = (ROOT / "scenes/main.tscn").read_text(encoding="utf-8")

assert 'config/name="SERA v119 - Command Nexus Startup Fix"' in project
assert 'run/main_scene="res://scenes/launch_menu.tscn"' in project
assert 'pointing/emulate_mouse_from_touch=false' in project, "Keep raw combat touch settings"
assert 'path="res://scripts/launch_menu.gd"' in menu_scene
assert 'path="res://scripts/command_nexus.gd"' in base_scene

# All layout is declarative, anchored to its parent instead of shifted by manual offsets.
assert 'anchor_right = 1.0' in menu_scene
assert 'anchor_bottom = 1.0' in menu_scene
assert 'type="CenterContainer"' in menu_scene
assert 'type="MarginContainer"' in menu_scene
assert 'position = Vector2(' not in menu_scene
assert 'position = Vector2(' not in menu_script
assert 'name="TrainingButton" type="Button"' in menu_scene
assert 'name="NexusButton" type="Button"' in menu_scene
assert 'custom_minimum_size.x = maxf(0.0, minf(500.0, size.x - 72.0))' in menu_script

# Android touch is converted into a click only while selector is active.
assert 'Input.emulate_mouse_from_touch = true' in menu_script
assert 'Input.emulate_mouse_from_touch = _previous_mouse_emulation' in menu_script
assert 'training_button.pressed.connect(_open_scene.bind(TRAINING_SCENE))' in menu_script
assert 'nexus_button.pressed.connect(_open_scene.bind(NEXUS_SCENE))' in menu_script
assert 'get_tree().change_scene_to_file(scene_path)' in menu_script
assert 'if result != OK:' in menu_script
assert 'error_label.visible = true' in menu_script

# Command Nexus must compile against Godot 4's Environment enum.
assert 'Environment.AMBIENT_SOURCE_COLOR' in base_script
assert 'Environment.AMBIENT_COLOR' not in base_script
assert 'env.ambient_light_sky_contribution = 0.0' in base_script
assert 'func _gate() -> void:' in base_script
assert 'func _terminal(' in base_script
assert 'res://scripts/sera_rig.gd' in base_script

# Original training scene and model stay selectable/available.
assert 'path="res://scripts/main.gd"' in training_scene
assert 'TRAINING_SCENE: String = "res://scenes/main.tscn"' in menu_script
assert 'NEXUS_SCENE: String = "res://scenes/command_nexus.tscn"' in menu_script
assert (ROOT / "blockbench/SERA_Command_Nexus_LowPoly.bbmodel").is_file()
print("v119 startup layout, navigation, touch and base enum static checks: PASS")
print("Godot editor and Android runtime not tested by this script.")
