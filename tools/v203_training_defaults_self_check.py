#!/usr/bin/env python3
"""SERA v203: NEXUS training target defaults and training-start emphasis."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

nexus = read("scripts/command_nexus.gd")
main = read("scripts/main.gd")
debug = read("scripts/enemy_debug_ui.gd")
settings = read("scripts/training_defaults.gd")
project = read("project.godot")

version = re.search(r'^config/name="SERA v(\d+)"$', project, re.M)
assert version and int(version.group(1)) >= 203
assert (ROOT / "README_v203_ja.md").is_file()

for token in (
    'const SETTINGS_PATH: String = "user://sera_training_defaults.cfg"',
    '"move_enabled": bool(config.get_value("target", "move_enabled", true))',
    '"auto_fire_enabled": bool(config.get_value("target", "auto_fire_enabled", true))',
    '"attack_type": clampi(int(config.get_value("target", "attack_type", 0)), 0, 3)',
    "return config.save(SETTINGS_PATH)",
):
    assert token in settings, token

for token in (
    "training_settings = TrainingDefaults.load_defaults()",
    'for option_name in ["TARGET MOTION", "AUTO ATTACK", "ATTACK TYPE"]:',
    'training_settings["move_enabled"] = not bool(',
    'training_settings["auto_fire_enabled"] = not bool(',
    'training_settings["attack_type"] = (int(',
    "TrainingDefaults.save_defaults(training_settings)",
    "_tap_training_control(point)",
    "_set_training_visible(target_name == \"TRAINING\")",
    '_layout_training_controls()',
    'action_label.text = ">>  TRAINING START  <<"',
    'training_start_style.set_border_width_all(3)' if False else 'style.set_border_width_all(3)',
    'training_start_pulse * TAU / 1.8',
):
    assert token in nexus, token

for token in (
    "target_move_enabled = bool(training_settings.get(\"move_enabled\", true))",
    'enemy_shooter.set("selected_attack", int(training_settings.get("attack_type", 0)))',
    'enemy_shooter.set("auto_fire_enabled", bool(training_settings.get("auto_fire_enabled", true)))',
    'enemy_debug_ui.call("apply_initial_defaults",',
    'move_target_button.text = "MOVE: ON" if target_move_enabled else "MOVE: OFF"',
):
    assert token in main, token

assert 'func apply_initial_defaults(attack_type: int, auto_enabled: bool)' in debug
assert 'set_pressed_no_signal(auto_enabled)' in debug
assert "change_scene_to_file(TRAINING_SCENE)" in nexus
print("v203 training defaults source checks passed")
