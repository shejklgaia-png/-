#!/usr/bin/env python3
"""v166: training -> Command Nexus navigation static source contract.

Does not execute Godot or emulate Android touch.
"""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
project = (root / "project.godot").read_text(encoding="utf-8")
training = (root / "scripts/main.gd").read_text(encoding="utf-8")
nexus = (root / "scripts/command_nexus.gd").read_text(encoding="utf-8")
launcher = (root / "scripts/launch_menu.gd").read_text(encoding="utf-8")

if re.findall(r'^config/name="([^"]+)"$', project, re.MULTILINE) != ["SERA v166"]:
    print("SKIP: v166 historical regression test (current project is newer)")
    raise SystemExit(0)
assert 'run/main_scene="res://scenes/launch_menu.tscn"' in project
assert 'const NEXUS_SCENE: String = "res://scenes/command_nexus.tscn"' in training
assert (root / "scenes/command_nexus.tscn").is_file()
assert 'get_tree().change_scene_to_file(NEXUS_SCENE)' in training
assert 'call_deferred("_change_to_nexus")' in training
assert 'if _returning_to_nexus:' in training
assert '_returning_to_nexus = false' in training
assert 'nexus_button.text = "BACK TO NEXUS"' in training
assert 'nexus_button.pressed.connect(_request_return_to_nexus)' in training
assert 'nexus_button.mouse_filter = Control.MOUSE_FILTER_STOP' in training
assert 'if _pointer_on_nexus_button(event.position):' in training
assert 'step_hud_touch = event.index' in training
assert 'step_hud_mouse_press = true' in training
assert 'get_viewport().set_input_as_handled()' in training
assert 'if _pointer_on_step_hud(event.position):' in training
assert 'if event.is_action_pressed("ui_cancel") or event.keycode == KEY_BACK:' in training
assert 'what == NOTIFICATION_WM_GO_BACK_REQUEST' in training
assert 'get_tree().quit_on_go_back = false' in training
assert 'get_tree().quit_on_go_back = _previous_quit_on_go_back' in training
assert 'const TRAINING_SCENE: String = "res://scenes/main.tscn"' in nexus
assert 'get_tree().change_scene_to_file(TRAINING_SCENE)' in nexus
assert 'training_button.pressed.connect(_open_scene.bind(TRAINING_SCENE))' in launcher
assert 'JUMP_TOUCH_INPUT_ENABLED: bool = false' in training
assert 'const STRIKE_DAMAGE = [12, 12, 26]' in training
assert (root / "README_v166_ja.md").is_file()
print("PASS: v166 training -> Nexus navigation, Android touch/back and PC input wired")
print("PASS: previous Nexus -> training route and combat touch guard intact")
print("Godot engine and Android: NOT TESTED")
