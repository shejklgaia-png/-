#!/usr/bin/env python3
"""v488 base/menu boundary: independent requirements for the overworld NEXUS building."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

scene = read("scenes/base_exploration.tscn")
base = read("scripts/base_exploration.gd")
nexus = read("scripts/command_nexus.gd")
project = read("project.godot")
save = read("scripts/sera_save.gd")

assert 'res://scripts/base_exploration.gd' in scene
assert 'extends Node3D' in base
assert 'res://scripts/sera_rig.gd' in base
assert 'func _move_player(' in base, "Overworld SERA movement must stay available"
assert 'func _create_crate(' in base
assert 'func _update_crate(' in base, "CRATE must wander autonomously in overworld"
assert 'CRATE_WAYPOINTS' in base
assert 'func _build_nexus_building(' in base
assert 'func _nexus_screen_rect(' in base
assert 'func _nexus_hit(' in base, "tap NEXUS's visible 3D building, not a generic shortcut"
assert 'func _enter_nexus(' in base
assert 'InputEventScreenTouch' in base and 'InputEventScreenDrag' in base
assert 'Control.MOUSE_FILTER_IGNORE' in base
assert 'change_scene_to_file(NEXUS_SCENE)' in base
assert 'var requested_nexus_target: String = ""' in save
# The five original NEXUS submenus stay inside NEXUS, not five exterior stations.
assert 'const STATIONS =' not in base
assert 'func _nearest_station(' not in base
assert 'func _interact(' not in base
assert 'func _open_nexus(' not in base
assert 'nexus_panel' not in base, "building is tapped instead of using top-right shortcut"
# The existing NEXUS is a stationary equipment/system interface, not walkable.
assert 'const BASE_SCENE: String = "res://scenes/base_exploration.tscn"' in nexus
assert 'func _enter_base() -> void:' in nexus
assert 'get_tree().change_scene_to_file(BASE_SCENE)' in nexus
assert 'EXIT TO BASE' in nexus
assert 'func _move_player(' not in nexus
assert 'func _update_crate(' not in nexus
assert 'func _select_target(target_name: String) -> void:' in nexus
assert 'res://scenes/bittaran_battle.tscn' in nexus
assert 'run/main_scene="res://scenes/base_exploration.tscn"' in project
assert 'pointing/emulate_mouse_from_touch=false' in project
print("SERA_BASE_HUB_NAVIGATION_STATIC_PASS")
