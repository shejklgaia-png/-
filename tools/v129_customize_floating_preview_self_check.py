#!/usr/bin/env python3
"""SERA v129: floating camera-facing model preview with in-place spin.

Static/source regression only. Requires actual Godot/Android run for visual checks.
"""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
s = (ROOT / "scripts/command_nexus.gd").read_text(encoding="utf-8")
project = (ROOT / "project.godot").read_text(encoding="utf-8")
model = json.loads((ROOT / "models/SERA_BOOSTER_allテスト.bbmodel").read_text(encoding="utf-8"))

assert 'config/name="SERA v146 - Bounded visual transfer"' in project
assert 'run/main_scene="res://scenes/launch_menu.tscn"' in project
assert 'pointing/emulate_mouse_from_touch=false' in project
assert 'renderer/rendering_method="gl_compatibility"' in project

# Use original SERA instance; avoid reparent() since SeraRig._exit_tree()
# cleans externally-owned afterimage meshes during removal from scene tree.
assert s.count("SeraRig.new()") == 1
assert ".reparent(" not in s
assert "sera_display_stand = stand" in s
assert "sera_display_rig = rig" in s
assert "sera_original_transform = rig.transform" in s
assert "sera_display_rig.global_transform = cam.global_transform * Transform3D(" in s
assert "sera_display_rig.transform = sera_original_transform" in s
assert "func _show_customization_preview()" in s
assert "func _restore_customization_preview()" in s
# On tap, fit the SERA pose in the target camera frame and start both Tweens.
assert 'if target_name == "CUSTOMIZE":' in s
assert '_show_customization_preview()' in s
assert 'cam.transform = previous_camera_pose' in s
assert 'cam.fov = previous_camera_fov' in s
# v141 Back starts rig retraction and overview camera at the same time.
assert 'if focused_target == "CUSTOMIZE" and customize_preview_active:' in s
assert '_begin_customization_retraction()' in s
assert 'customize_entrance_tween.finished.connect(_customization_retraction_arrived)' in s
assert 'func _customization_retraction_arrived() -> void:' in s
# On CUSTOMIZE Back the retract and camera calls are adjacent in the
# same event callback. Their Tween completion is coordinated independently.
assert 'if focused_target == "CUSTOMIZE" and customize_preview_active:' in s
assert '_begin_customization_retraction()' in s
assert '_move_camera(overview_pose, overview_fov, _overview_arrived)' in s

# Front facing in the camera's own coordinate system, with model-only rotation.
assert "customize_preview_yaw = PI" in s
assert "Basis(Vector3.UP, customize_preview_yaw)" in s
assert "CUSTOMIZE_PREVIEW_DISTANCE: float = 3.25" in s
assert "CUSTOMIZE_PREVIEW_ROTATION_SAMPLES: int = 16" in s
assert "func _customization_all_yaw_bounds()" in s
assert "for i in range(CUSTOMIZE_PREVIEW_ROTATION_SAMPLES)" in s
assert "customize_preview_scale *= fit" in s
assert "func _fit_customization_preview()" in s
assert 'PANEL_LAYOUTS["CUSTOMIZE"]' in s
assert 'func _customize_model_area(view: Vector2) -> Rect2:' in s
assert 'var frame: Rect2 = _customize_model_area(size)' in s
assert 'var target_width: float = minf(size.x * CUSTOMIZE_PREVIEW_TARGET_WIDTH_RATIO,' in s
assert "func _customization_screen_bounds()" in s
assert 'target_parts["CUSTOMIZE"] = grouped.values()' in s
assert "piece.is_visible_in_tree()" in s
assert "focus_panel.add_theme_stylebox_override(\"panel\", _menu_body_style())" in s
assert "focus_header.add_theme_stylebox_override(\"panel\", _menu_header_style())" in s

# Raw touch gesture and PC mouse gesture, originating only in non-menu model area.
assert "func _is_customization_drag_zone(pixel: Vector2)" in s
assert 'focused_target != "CUSTOMIZE"' in s
assert "Rect2(focus_panel.position, focus_panel.size).has_point(pixel)" in s
assert "Rect2(back_panel.position, back_panel.size).has_point(pixel)" in s
assert "event is InputEventScreenDrag" in s
assert "event is InputEventScreenTouch" in s
assert "event.index == customize_touch_id" in s
assert "event is InputEventMouseMotion and customize_mouse_drag" in s
assert "customize_mouse_drag = false" in s
assert "customize_touch_id = -1" in s
assert "customize_preview_yaw = wrapf(customize_preview_yaw - yaw_delta, -PI, PI)" in s
assert "CUSTOMIZE_DRAG_FULL_TURN: float = TAU" in s
assert "func _rotate_customization_preview(delta_x: float)" in s
rotate_part = s.split("func _rotate_customization_preview(delta_x: float)",1)[1].split("func _update_projected_silhouettes()",1)[0]
assert "cam.position =" not in rotate_part
assert "cam.transform =" not in rotate_part
assert "cam.rotation =" not in rotate_part
assert "_apply_customization_preview_transform()" in rotate_part

# v128 layout/camera, v127 occlusion, v125 transition/Back remain.
assert '"CUSTOMIZE": {"eye": Vector3(-4.50, 3.80, 5.00)' in s
assert 'CAMERA_TRANSITION_SECONDS: float = 0.18' in s
assert 'back_panel.position = Vector2(view.x - margin - 62.0, view.y - margin - 62.0)' in s
assert 'Geometry2D.clip_polyline_with_polygon(segment, mask)' in s
assert 'selected_shape = "SYSTEM" if at.x < 0.0 else "TRAINING"' in s
assert "get_tree().change_scene_to_file(TRAINING_SCENE)" in s
clips = {x["name"]: x for x in model["animations"]}
assert "Bash" in clips and "Guard_REACTION" in clips
assert len(clips["Bash"]["animators"]) >= 1
print("v129 floating SERA, preserved hangar, 360-safe fit, touch/mouse yaw and restore: PASS")
print("Static checks only; Godot parser, preview appearance and Android touch are unverified.")
