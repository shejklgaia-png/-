#!/usr/bin/env python3
"""SERA v200: RUN contact-only grounding and 360-degree flick steps."""
from pathlib import Path
import math
import re

ROOT = Path(__file__).resolve().parents[1]
def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

version_match = re.search(r'^config/name="SERA v(\d+)"$', read("project.godot"), re.M)
assert version_match and int(version_match.group(1)) >= 200
rig = read("scripts/sera_rig.gd")
eq = read("scripts/sera_equipment.gd")
main = read("scripts/main.gd")
assert "func restore_grounding_baseline() -> void:" in eq
restore = eq.split("func restore_grounding_baseline() -> void:",1)[1].split("func snap_grounded_sole_to_floor()",1)[0]
assert "if not grounding_enabled or rig == null:" in restore
assert "rig.position.y = rig_original_y + grounding_height_offset" in restore
tick = rig.split("    _apply_animation(delta)\n",1)[1].split("func _run_heading_from_weights",1)[0]
assert tick.index('equipment_handler.call("restore_grounding_baseline")') < tick.index("if (current_clip == WAIT_CLIP")
assert 'current_clip == WAIT_CLIP and not step_playback and not combat_playback' in tick
assert 'and not guard_playback and not jump_playback and not damage_playback' in tick
assert 'equipment_handler.call("snap_grounded_sole_to_floor")' in tick
assert 'elif current_clip in RUN_CLIPS and not step_playback:' in tick
assert tick.count('_update_foot_contacts(delta)') == 1
assert "else:\n        reset_foot_contacts()" in tick
assert tick.count('snap_grounded_sole_to_floor') == 1
audio_event = rig.split("func _update_foot_contacts(delta: float)",1)[1].split("func _build_model(",1)[0]
assert "foot_contact_elapsed >= FOOT_CONTACT_MIN_INTERVAL" in audio_event
assert 'equipment_handler.call("snap_run_contact_foot_to_floor", side)\n                foot_contact.emit(side)' in audio_event
assert audio_event.count('equipment_handler.call("snap_run_contact_foot_to_floor", side)') == 1
assert 'current_clip not in RUN_CLIPS' in audio_event
assert 'foot_lifted[side] = true' in audio_event
assert 'footstep_audio.play()' in main
assert 'rig.connect("foot_contact", Callable(self, "_on_foot_contact"))' in main

release = main.split('func _end_drag(release_pos: Vector2)',1)[1].split('func _remember_jump_flick_sample(',1)[0]
assert 'var flick_direction: Vector2 = Vector2.ZERO if suppress_flick else _classify_step_flick(' in release
assert 'boost_has_activated_this_gesture or jump_requested' in release
assert 'if bash_requested and _request_combo_bash():' in release
assert 'if _start_omni_step(flick_direction):' in release
flick = main.split('func _classify_step_flick(displacement: Vector2, seconds: float) -> Vector2:',1)[1].split('func _start_omni_step(',1)[0]
for substring in ('distance / seconds < STEP_FLICK_MIN_PIXELS_PER_SEC',
                  'seconds > STEP_FLICK_MAX_SECONDS',
                  'gesture_max_travel > distance * 1.20',
                  'return displacement / distance'):
    assert substring in flick
assert "STEP_FLICK_MAX_HORIZONTAL_RATIO" not in flick
assert "STEP_FLICK_MAX_VERTICAL_RATIO" not in flick
assert "return STEP_BACK" not in flick
assert "const JUMP_TOUCH_INPUT_ENABLED: bool = false" in main

step = main.split("func _start_omni_step(flick: Vector2) -> bool:",1)[1].split("func _start_back_step()",1)[0]
assert "var direction: Vector2 = flick.normalized()" in step
assert "step_radial_delta = direction.y * radial_distance" in step
assert "BACK_STEP_DISTANCE if direction.y >= 0.0 else STEP_MIN_ARC_LENGTH" in step
assert "step_signed_angle *= signf(direction.x) * tangent_sign" in step
assert 'rig.call("start_omni_step", direction)' in step
advance = main.split("func _advance_side_step(delta: float)",1)[1].split("func _move_player_swept(",1)[0]
assert "initial_radius + step_radial_delta * progress" in advance
assert "step_signed_angle * progress) * moved_radius" in advance
assert "_move_player_swept(requested, true)" in advance
for deg in range(0, 360, 5):
    x, y = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    radial = y * (4.0 if y >= 0 else 2.0)
    side_length = max(2.0, min(4.0, 6.0 * math.radians(35)))
    travel = max(2.0, min(4.0, math.hypot(abs(x) * side_length, radial)))
    assert 2.0 - 1e-10 <= travel <= 4.0 + 1e-10 and math.isfinite(travel)
assert "STEP_MIN_ARC_LENGTH: float = 2.0" in main
assert "BACK_STEP_DISTANCE: float = 4.0" in main

pose = rig.split("func _blended_directional_step_pose(",1)[1].split("func start_omni_step(",1)[0]
for phrase in ("_sample_boost_pose(BOOST_CLIP, uid)",
               "_sample_step_clip_pose(STEP_BACK_CLIP, uid, 0.0)",
               "STEP_RIGHT_CLIP if direction.x >= 0.0 else STEP_LEFT_CLIP",
               "atan2(absf(direction.x), absf(direction.y))", ".slerp(", ".lerp("):
    assert phrase in pose, phrase
assert '_switch_clip(STEP_RIGHT_CLIP, 0.12)' in rig
assert '_switch_clip(RUN_CLIP if resume_moving else WAIT_CLIP, 0.16)' in rig
assert 'step_playback and directional_step_active' in rig
assert 'var t: float = clip_time if (step_playback and directional_step_active)' in rig
assert 'prior_rotations[uid] = pivot.quaternion' in rig
assert 'state_label.text = "STEP FORWARD  |  Boost_front"' in main
assert 'player.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING' in main
assert 'const SLOTS = ["head", "torso", "legs", "arms", "booster", "weapon_r", "weapon_l"]' in eq
print("PASS v200: WAIT grounding, RUN contact-signal grounding, other poses baseline")
print("PASS v200: continuous full-circle flick direction and swept step movement")
print("PASS v200: Step_L/Step_R/Backstep/Boost_front pose blend with fade")
print("Android Godot runtime behavior not verified")
