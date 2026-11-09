#!/usr/bin/env python3
"""v127: swapped front-console actions, occluded gate stroke, thicker outlines.

Static source/asset regression; Godot/Android visual/runtime remain untested.
"""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
script = (ROOT / "scripts/command_nexus.gd").read_text(encoding="utf-8")
outline = (ROOT / "scripts/nexus_selection_outline.gd").read_text(encoding="utf-8")
project = (ROOT / "project.godot").read_text(encoding="utf-8")
model = json.loads((ROOT / "models/SERA_BOOSTER_allテスト.bbmodel").read_text(encoding="utf-8"))

assert 'config/name="SERA v151"' in project
assert 'run/main_scene="res://scenes/launch_menu.tscn"' in project
assert 'pointing/emulate_mouse_from_touch=false' in project

# Physical console positions, angles, and authored geometry remain exactly v126.
assert '_module("kiosk", Vector3(-1.95, 0.0, 1.30), deg_to_rad(36.0))' in script
assert '_module("kiosk", Vector3(1.95, 0.0, 1.30), deg_to_rad(-36.0))' in script
assert 'selected_shape = "SYSTEM" if at.x < 0.0 else "TRAINING"' in script
assert '"TRAINING": {"eye": Vector3(1.95, 3.15, 7.70)' in script
assert '"look": Vector3(0.45, 1.35, 1.25), "fov": 68.0' in script
assert '"SYSTEM": {"eye": Vector3(-1.95, 3.15, 7.70)' in script
assert '"look": Vector3(-0.45, 1.35, 1.25), "fov": 68.0' in script
assert 'if focused_target == "TRAINING" and focus_panel.visible:' in script
assert 'get_tree().change_scene_to_file(TRAINING_SCENE)' in script

# Model-derived SERA mask clips only the gate's 2D stroke.
assert 'if contours.has("DEPLOYMENT"):' in script
assert 'sera_masks = _project_model_contour("CUSTOMIZE")' in script
assert 'visible_strokes["DEPLOYMENT"] = _clip_gate_strokes(' in script
assert 'func _clip_gate_strokes(gate_shapes: Array, occluders: Array)' in script
assert 'Geometry2D.offset_polygon(' in script
assert 'Geometry2D.clip_polyline_with_polygon(segment, mask)' in script
assert 'outline.set("clipped_strokes", visible_strokes)' in script
assert 'closed.append(shape[0])' in script
assert 'if not _polygon_bounds(segment).intersects(mask_bounds):' in script
assert 'var clipped_strokes: Dictionary = {}' in outline
assert 'if clipped_strokes.has(name):' in outline
assert 'draw_polyline(fragment, stroke, thickness, true)' in outline
assert 'draw_polyline(closed, stroke, thickness, true)' in outline
assert 'var thickness := 5.0 if selected else 4.5' in outline

# Both normal and selected contour keep the same blink/focus behavior.
assert 'sin(pulse_time * 3.6)' in outline
assert '0.98 if selected else 0.15 + 0.47 * blink' in outline
assert 'CAMERA_TRANSITION_SECONDS: float = 0.18' in script
assert 'back_panel.position = Vector2(view.x - margin - 62.0, view.y - margin - 62.0)' in script
assert 'KEY_BACK' in script and 'InputEventScreenTouch' in script
assert 'GPUParticles3D' not in script
assert 'CPUParticles3D' not in script

# Do not alter the user-authored character model or its new animations.
clips = {a["name"]: a for a in model["animations"]}
assert "Bash" in clips and "Guard_REACTION" in clips
assert len(clips["Bash"]["animators"]) >= 1
print("v127 kiosk mapping, occlusion-safe gate clipping and thick pulse strokes: PASS")
print("Source-only validation; actual Godot/Android runtime and visual look remain untested.")
