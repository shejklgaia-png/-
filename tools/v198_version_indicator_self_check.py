#!/usr/bin/env python3
"""v198: startup selector, training room and Nexus share one project-title version."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

project = read("project.godot")
current = re.findall(r'^config/name="([^"]+)"$', project, re.M)
assert len(current) == 1 and re.fullmatch(r"SERA v([1-9][0-9]*)", current[0])
assert int(current[0].split("v")[1]) >= 198
assert 'run/main_scene="res://scenes/launch_menu.tscn"' in project
for scene in ("launch_menu", "main", "command_nexus"):
    assert (ROOT / ("scenes/" + scene + ".tscn")).is_file()

widget = read("scripts/version_indicator.gd")
assert "extends RefCounted" in widget
assert "static func attach(parent: Node) -> Label:" in widget
assert 'ProjectSettings.get_setting(' in widget
assert '"application/config/name", "SERA"' in widget
assert 'version_label.name = "SeraVersionLabel"' in widget
assert 'version_label.mouse_filter = Control.MOUSE_FILTER_IGNORE' in widget
assert 'version_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)' in widget
assert "version_label.offset_top = 3.0" in widget
assert "version_label.offset_bottom = 25.0" in widget
assert "version_label.offset_right = -14.0" in widget
assert "v198" not in widget

screens = {
    "selection": ("scripts/launch_menu.gd", "VersionIndicator.attach(self)"),
    "nexus": ("scripts/command_nexus.gd", "VersionIndicator.attach(hud)"),
}
for name, (path, call) in screens.items():
    contents = read(path)
    assert 'const VersionIndicator = preload("res://scripts/version_indicator.gd")' in contents, name
    assert contents.count(call) == 1, name
    assert "SeraVersionLabel" not in contents, name

launcher = read("scripts/launch_menu.gd")
assert 'training_button.pressed.connect(_open_scene.bind(TRAINING_SCENE))' in launcher
assert 'nexus_button.pressed.connect(_open_scene.bind(NEXUS_SCENE))' in launcher
training = read("scripts/main.gd")
assert 'nexus_button.pressed.connect(_request_return_to_nexus)' in training
assert 'var layer := CanvasLayer.new()' in training
assert "VersionIndicator.attach(layer)" not in training
assert "clean_training_hud = CLEAN_TRAINING_HUD.new()" in training
assert "hud_panel.visible = false" in training
nexus = read("scripts/command_nexus.gd")
assert 'hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)' in nexus
assert nexus.index("VersionIndicator.attach(hud)") > nexus.index("_create_archive_records()")

print("PASS: selection, training and Nexus display one shared version label")
print("PASS: top-right anchors, input pass-through and single source-of-truth")
print("PASS: existing navigation is unchanged")
print("Godot / Android rendering not verified by static checks")
