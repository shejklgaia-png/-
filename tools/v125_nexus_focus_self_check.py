#!/usr/bin/env python3
"""v125 interactive Nexus: static source/projection regression (not Godot runtime)."""
from pathlib import Path
import math
import re

ROOT = Path(__file__).resolve().parents[1]
nexus = (ROOT / "scripts/command_nexus.gd").read_text(encoding="utf-8")
overlay = (ROOT / "scripts/nexus_selection_outline.gd").read_text(encoding="utf-8")
project = (ROOT / "project.godot").read_text(encoding="utf-8")
model = (ROOT / "models/SERA_BOOSTER_allテスト.bbmodel").read_text(encoding="utf-8")

assert 'config/name="SERA v133 - Immediate selection feedback"' in project
assert 'run/main_scene="res://scenes/launch_menu.tscn"' in project
assert 'pointing/emulate_mouse_from_touch=false' in project
assert 'renderer/rendering_method="gl_compatibility"' in project

# The overview has no text signplates or input-emulation changes.
assert 'func _tag(' not in nexus
assert 'TagIcon.new()' not in nexus
assert 'Input.emulate_mouse_from_touch = true' not in nexus
assert 'InputEventScreenTouch' in nexus
assert 'InputEventMouseButton' in nexus
assert 'KEY_BACK' in nexus
assert 'func _return_to_overview()' in nexus
assert 'func _start_training()' in nexus
assert 'get_tree().change_scene_to_file(TRAINING_SCENE)' in nexus
assert 'TRAINING_SCENE: String = "res://scenes/main.tscn"' in nexus

# Camera focus is 0.18 seconds, with no extra screen or particle effects.
assert 'CAMERA_TRANSITION_SECONDS: float = 0.18' in nexus
assert 'Tween.TRANS_CUBIC' in nexus and 'Tween.EASE_OUT' in nexus
assert 'from_pose.interpolate_with(to_pose, progress)' in nexus
assert 'lerpf(from_fov, to_fov, progress)' in nexus
assert 'func _focus_arrived(' in nexus
assert 'func _overview_arrived()' in nexus
assert 'GPUParticles3D' not in nexus and 'CPUParticles3D' not in nexus
assert 'Button.new()' not in nexus
assert 'draw_polyline' in overlay
assert 'sin(pulse_time * 3.6)' in overlay

# Outline is bound to the 3D camera, not a fixed 2D HUD sign.
assert 'cam.unproject_position(world_point)' in nexus
assert 'Geometry2D.is_point_in_polygon(point, poly)' in nexus
assert 'func _polygon_bounds(' in nexus
assert 'outline.set("active_target", target_name)' in nexus
assert 'outline.set("active_target", "")' in nexus

targets = ("TRAINING", "SYSTEM", "CUSTOMIZE", "DATA ARCHIVE", "DEPLOYMENT")
assert all(f'"{t}": {{"eye":' in nexus for t in targets)
assert 'target_parts: Dictionary' in nexus
assert '_capture_sera_silhouette(rig)' in nexus
assert len(re.findall(r'"eye": Vector3\(', nexus)) == 5
assert len(re.findall(r'"look": Vector3\(', nexus)) == 5

# v126 removed fixed approximated six-point hulls in favor of actual
# Blockbench / SERA mesh vertices projected from the changing camera.
assert "target_hulls" not in nexus
assert "Geometry2D.convex_hull(screen_points)" in nexus
assert "Geometry2D.merge_polygons(" in nexus
assert "Geometry2D.offset_polygon(" in nexus
assert "piece.mesh.get_aabb()" in nexus
assert "func _collect_sera_geometry(" in nexus
assert "view.x - margin - 62.0" in nexus
assert "view.y - margin - 62.0" in nexus

assert 'Bash' in model and 'Guard_REACTION' in model

# The authored scene, model, modules and gate light setup remain available.
assert 'const GATE_ORIGIN: Vector3 = Vector3(4.00, 0.02, -10.48)' in nexus
assert 'var lamp := OmniLight3D.new()' in nexus
assert '_module("archive_mezzanine", Vector3(-4.00, 0.0, -6.55))' in nexus
assert 'SeraRig.new()' in nexus
assert (ROOT / "scenes/main.tscn").exists()
print("v125 focus and touch regression with v126 model contours: PASS")
print("Static/projection test only; Godot parser, Android viewport and touch remain untested.")
