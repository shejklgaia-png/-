#!/usr/bin/env python3
"""v126: low-cost contours derived from real 3D module and SERA meshes.

Static-only test: no Godot parser, mobile GPU or Android touch execution.
"""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
script = (ROOT / "scripts/command_nexus.gd").read_text(encoding="utf-8")
stroke = (ROOT / "scripts/nexus_selection_outline.gd").read_text(encoding="utf-8")
project = (ROOT / "project.godot").read_text(encoding="utf-8")
base = (ROOT / "assets/base_command_modules.gd").read_text(encoding="utf-8")
original = json.loads(base.split("const MODULES = ", 1)[1].strip())
model = json.loads((ROOT / "models/SERA_BOOSTER_allテスト.bbmodel").read_text(encoding="utf-8"))

assert 'config/name="SERA v151"' in project
assert 'run/main_scene="res://scenes/launch_menu.tscn"' in project
assert 'pointing/emulate_mouse_from_touch=false' in project
assert 'renderer/rendering_method="gl_compatibility"' in project

# Same BoxMesh and transforms that render each Blockbench prop create its hull.
assert "target_hulls" not in script
assert 'var target_parts: Dictionary' in script
assert 'corners.append(transform * Vector3(ix, iy, iz))' in script
assert 'var silhouette_parts: Array = target_parts.get(selected_shape, [])' in script
for prop, target in (("data_bank", "DATA ARCHIVE"), ("deployment_gate", "DEPLOYMENT")):
    assert f'"{prop}":\n            selected_shape = "{target}"' in script
assert 'selected_shape = "SYSTEM" if at.x < 0.0 else "TRAINING"' in script
assert 'target_parts["CUSTOMIZE"] = grouped.values()' in script
assert 'piece.mesh.get_aabb()' in script
assert 'piece.global_transform * local' in script
assert 'piece.is_visible_in_tree()' in script
assert 'Geometry2D.convex_hull(screen_points)' in script
assert 'Geometry2D.offset_polygon(' in script
assert 'Geometry2D.merge_polygons(' in script
assert 'Geometry2D.intersect_polygons(' in script
assert 'cam.unproject_position(world_point)' in script

# Projection/collision geometry is cached during idle and updated during tween.
assert 'func _process(_delta: float)' not in script
assert 'func _update_projected_silhouettes()' in script
assert 'func _apply_camera_transition(' in script
assert 'cam.fov = lerpf(from_fov, to_fov, progress)\n    _update_projected_silhouettes()' in script
assert 'outline.set("polygons", contours)' in script
assert 'Geometry2D.is_point_in_polygon(point, poly)' in script
assert 'var contours: Array = polys[candidate]' in script
assert 'var contours: Array = polygons[name]' in stroke

# Unselected contours blink. Focused contours become bright, without particles.
assert 'sin(pulse_time * 3.6)' in stroke
assert '0.98 if selected else 0.15 + 0.47 * blink' in stroke
assert 'draw_polyline(closed, stroke, thickness, true)' in stroke
assert 'GPUParticles3D' not in script
assert 'CPUParticles3D' not in script
assert 'MultiMeshInstance3D.new()' in script  # only existing batched prop geometry
assert 'func _tag(' not in script
assert 'TagIcon.new()' not in script

# Bottom-right back, clear of the menu (also on shorter portrait screens).
assert 'back_panel.position = Vector2(view.x - margin - 62.0, view.y - margin - 62.0)' in script
assert 'back_panel.position.y - focus_panel.size.y - 12.0' in script
assert 'Rect2(back_panel.position, back_panel.size).has_point(point)' in script
assert 'KEY_BACK' in script
assert 'CAMERA_TRANSITION_SECONDS: float = 0.18' in script
assert 'Tween.TRANS_CUBIC' in script and 'Tween.EASE_OUT' in script
assert 'InputEventScreenTouch' in script and 'InputEventMouseButton' in script
assert 'get_tree().change_scene_to_file(TRAINING_SCENE)' in script

# No original Blockbench assets or combat animations were changed by the UI.
assert len(original["kiosk"]) == 19
assert len(original["data_bank"]) == 17
assert len(original["deployment_gate"]) == 34
assert len(original["archive_mezzanine"]) == 37
animations = {a["name"]: a for a in model["animations"]}
assert "Bash" in animations and "Guard_REACTION" in animations
assert len(animations["Bash"]["animators"]) >= 1
assert (ROOT / "scenes/main.tscn").exists()

print("v126 real model outlines, cached projection, blink and bottom-right back: PASS")
print("Godot editor and Android runtime/visual alignment are NOT tested.")
