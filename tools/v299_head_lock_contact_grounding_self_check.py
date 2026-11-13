#!/usr/bin/env python3
"""v299: recover HEAD in shallow camera rays; floor-align WAIT/RUN contacts only."""
from pathlib import Path
import re

R = Path(__file__).resolve().parents[1]
read = lambda p: (R / p).read_text(encoding="utf-8")
project, target, rig, eq, main = map(read, (
    "project.godot", "scripts/target_parts.gd", "scripts/sera_rig.gd",
    "scripts/sera_equipment.gd", "scripts/main.gd"))
manifest = read("tools/sera_ci_manifest.txt")
assert int(re.search(r'config/name="SERA v(\d+)"', project).group(1)) >= 299
assert (R/"docs/history/release_notes/README_v299_ja.md").is_file()

assert 'const HEAD_LOCK_UPWARD_EXTENSION_METERS: float = 1.0' in target
assert 'const HEAD_LOCK_FORWARD_EXTENSION_METERS: float = 0.85' in target
selector = target.split('func _camera_center_line_part_distance(',1)[1].split(
    'func _camera_center_line_body_distance(',1)[0]
for token in (
    'if not is_targetable(id)',
    'for child in pivot.get_children():',
    'intersects_segment(',
    'if id == "head":',
    'Vector3(-head_size.x * 0.5, -head_size.y * 0.5,',
    'head_size.y + HEAD_LOCK_UPWARD_EXTENSION_METERS',
    'head_size.z + HEAD_LOCK_FORWARD_EXTENSION_METERS',
    'pivot.to_local(camera_origin), pivot.to_local(body_center)',
    'camera_origin.distance_squared_to(overhead_world)',
):
    assert token in selector, token
assert "get_part_aabb" not in selector
assert "get_part_aim_world" not in selector
body = target.split('func _camera_center_line_body_distance(',1)[1].split(
    'func camera_center_line_hits_part(',1)[0]
assert 'core_mesh.mesh is BoxMesh' in body
assert 'core_mesh.to_local(camera_origin)' in body
assert 'contact_world' in body
select = target.split('func select_actor_center_line_part(',1)[1].split(
    '# Read-only legacy camera-origin APIs',1)[0]
assert 'var closest: float = _camera_center_line_body_distance(' in select
assert 'if distance < closest:' in select

snap = eq.split('func snap_grounded_sole_to_floor()',1)[1].split(
    'func restore_run_contact_foot_positions()',1)[0]
assert 'get_active_foot_heights()' in snap
assert 'minf(float(heights["L"]), float(heights["R"]))' in snap
assert 'rig.position.y = TRAINING_VISIBLE_FLOOR_Y - current_sole - wearer.global_position.y' in snap

run = eq.split('func snap_run_contact_foot_to_floor(side: String)',1)[1].split(
    'func get_grounding_height_offset()',1)[0]
for token in (
    'side not in ["L", "R"]',
    'absf(wearer.global_position.y) > 0.05',
    'bool(rig.get("jump_playback"))',
    'get_active_foot_heights()',
    'minf(float(heights["L"]), float(heights["R"]))',
    'run_contact_visual_y = TRAINING_VISIBLE_FLOOR_Y - lowest - wearer.global_position.y',
    'rig.position.y = run_contact_visual_y',
):
    assert token in run, token
assert "piece.global_position +=" not in run
assert "func restore_run_contact_height()" in eq
assert "func clear_run_contact_height()" in eq
assert 'run_contact_visual_y = NAN' in eq
assert 'rig.position.y = rig_original_y + grounding_height_offset' in eq.split(
    'func restore_grounding_baseline()',1)[1].split('func smooth_bird_grounding',1)[0]

contacts = rig.split('func _update_foot_contacts(',1)[1].split('func _build_model(',1)[0]
assert 'foot_contact_elapsed >= FOOT_CONTACT_MIN_INTERVAL' in contacts
assert 'equipment_handler.call("snap_run_contact_foot_to_floor", side)' in contacts
assert contacts.count('equipment_handler.call("snap_run_contact_foot_to_floor", side)') == 1
assert 'current_for", "legs")) != "C"' not in contacts
tick = rig.split('    _apply_animation(delta)\n',1)[1].split('func _run_heading_from_weights',1)[0]
assert 'equipment_handler.call("restore_grounding_baseline")' in tick
assert 'equipment_handler.call("snap_grounded_sole_to_floor")' in tick
assert 'equipment_handler.call("restore_run_contact_height")' in tick
assert 'equipment_handler.call("clear_run_contact_height")' in tick
assert 'elif current_clip in RUN_CLIPS and not step_playback:' in tick
assert 'equipment_handler.call("smooth_bird_grounding", delta)' not in tick
assert tick.count('equipment_handler.call("snap_grounded_sole_to_floor")') == 1
assert '_update_foot_contacts(delta)' in tick
assert '_combo_lock_retention_active()' in main

for entry in (
    "py tools/v299_head_lock_contact_grounding_self_check.py",
    "gd tools/v299_head_lock_contact_grounding_runtime_check.gd",
):
    assert entry in manifest,entry
print("V299_HEAD_LOCK_CONTACT_GROUNDING_STATIC_PASS")
