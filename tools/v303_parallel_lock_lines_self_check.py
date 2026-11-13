#!/usr/bin/env python3
"""SERA v303: dual parallel AUTO lock rays with visible/hidden debug toggle."""
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
main=(root/"scripts/main.gd").read_text(encoding="utf-8")
parts=(root/"scripts/target_parts.gd").read_text(encoding="utf-8")
manifest=(root/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
project=(root/"project.godot").read_text(encoding="utf-8")
assert re.search(r'config/name="SERA v303"',project)
assert (root/"README_v303_ja.md").is_file()
assert "PARALLEL_LOCK_HALF_SPACING: float = 0.25" in parts
pair=parts.split("func get_actor_parallel_lock_segments(",1)[1].split(
    "func _parallel_lock_part_distance(",1)[0]
for term in ('var forward: Vector3 = body_center - actor_origin',
    'forward.y = 0.0',
    'lateral = Vector3(-forward.z, 0.0, forward.x)',
    'var side_offset: Vector3 = lateral * PARALLEL_LOCK_HALF_SPACING',
    'actor_origin - side_offset, body_center - side_offset',
    'actor_origin + side_offset, body_center + side_offset',
    'PackedVector3Array'):
    assert term in pair,term
distance=parts.split("func _parallel_lock_part_distance(",1)[1].split(
    "func actor_parallel_lines_hits_part(",1)[0]
for token in (
    '_camera_center_line_body_distance(segments[0], segments[1])',
    '_camera_center_line_body_distance(segments[2], segments[3])',
    '_camera_center_line_part_distance(segments[0], segments[1], id)',
    '_camera_center_line_part_distance(segments[2], segments[3], id)',
    'if first == INF or second == INF:',
    'return INF','return maxf(first, second)'):
    assert token in distance,token
hits=parts.split("func actor_parallel_lines_hits_part(",1)[1].split(
    "# Read-only legacy camera-origin APIs",1)[0]
assert 'return _parallel_lock_part_distance(segments, id) < INF' in hits
assert 'var closest: float = _parallel_lock_part_distance(segments, "")' in hits
assert 'for id in PART_ORDER:' in hits
assert 'if distance < closest:' in hits
auto=main.split("func _acquire_stable_camera_part(delta: float,",1)[1].split(
    "func _controller_start_area_contains(",1)[0]
assert '"select_actor_parallel_lines_part", sera_origin, center' in auto
assert '"actor_parallel_lines_hits_part",' in auto
assert 'sera_origin, center, locked_target_part_id' in auto
assert 'if not auto_lock_initialized or current_broken:' in auto
assert 'if not auto_lock_initialized or current_broken or not current_on_line:' not in auto
assert 'auto_lock_pending_elapsed >= AUTO_LOCK_SWITCH_CONFIRM_SECONDS' in auto
assert 'auto_lock_pending_part != preferred' in auto
assert 'preferred == locked_target_part_id and current_on_line' in auto
assert 'camera.global_position' not in auto
assert 'manual_part_lock_active' in main
assert 'or _combo_lock_retention_active()' in main

assert 'var lock_lines_visible: bool = false' in main
world=main.split("func _build_lock_line_visuals() -> void:",1)[1].split(
    "func _toggle_auto_lock_mode() -> void:",1)[0]
for token in (
    'lock_line_root.name = "DualLockRayDebug"',
    'lock_line_root.visible = lock_lines_visible',
    'material.no_depth_test = false',
    'material.render_priority = RENDER_ORDER.DEPTH_TESTED_EMISSIVE',
    'CylinderMesh.new()',
    'line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF',
    'lock_lines_button.text = "LINES ON" if lock_lines_visible else "LINES OFF"',
    'lock_lines_visible = not lock_lines_visible',
    '"get_actor_parallel_lock_segments"',
    'camera_player_render_position, camera_target_render_position',
    'line.global_position = (from_point + to_point) * 0.5',
    'line.global_basis = Basis(Quaternion(Vector3.UP, segment.normalized()))',
    'line.scale = Vector3(1.0, segment.length(), 1.0)'):
    assert token in world,token
ui=main.split('func _build_lock_switch_buttons(layer: CanvasLayer) -> void:',1)[1].split(
    'func _toggle_auto_lock_mode() -> void:',1)[0]
assert 'lock_lines_button.name = "LockLinesVisibility"' in ui
assert 'lock_lines_button.mouse_filter = Control.MOUSE_FILTER_IGNORE' in ui
assert 'CONTROLLER_BUTTON_TOP_INSET + LOCK_MODE_BUTTON_SIZE.y + 8.0' in ui
assert 'layer.add_child(lock_lines_button)' in ui
input_=main.split('func _input(event: InputEvent) -> void:',1)[1].split(
    'func _guard_can_start()',1)[0]
assert input_.count('_pointer_on_lock_lines_button(event.position)')==2
assert input_.count('_toggle_lock_lines()')==2
assert 'step_hud_touch = event.index' in input_
assert 'step_hud_mouse_press = true' in input_
assert 'get_viewport().set_input_as_handled()' in input_
process=main.split('func _process(delta: float) -> void:',1)[1]
assert '_update_lock_line_visuals()' in process
assert 'target_parts.call("select_actor_center_line_part"' not in auto
for entry in ('py tools/v303_parallel_lock_lines_self_check.py',
              'gd tools/v303_parallel_lock_lines_runtime_check.gd'):
    assert entry in manifest
print("V303_PARALLEL_LOCK_LINES_STATIC_PASS")
