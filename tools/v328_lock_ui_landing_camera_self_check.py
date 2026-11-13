#!/usr/bin/env python3
"""v328: saved lock mode, mirror layout, full landing STEP, target-first camera."""
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
main=(root/"scripts/main.gd").read_text()
nexus=(root/"scripts/command_nexus.gd").read_text()
icon=(root/"scripts/lock_site_icon.gd").read_text()
assert 'auto_lock_enabled = bool(settings.get_value(' in main
assert '"controls", "auto_lock_enabled", true' in main
assert 'settings.set_value("controls", "auto_lock_enabled", enabled)' in nexus
assert '"LOCK MODE  /  AUTO  >"' in nexus and '"LOCK MODE  /  MANUAL  >"' in nexus
assert 'system_lock_mode_row' in nexus and '_tap_system_control(' in nexus
assert 'var base: float = 0.5 if left_handed else 0.0' in main
assert 'button.text = "◀" if direction < 0 else "▶"' in main
assert 'lock_mode_button.text = ""' in main
assert 'lock_site_icon.gd' in main and 'draw_arc(' in icon
input_fn=main.split('func _input(event: InputEvent) -> void:',1)[1].split('func _guard_can_start()',1)[0]
assert '_toggle_auto_lock_mode()' not in input_fn
land=main.split('func _end_drag(release_pos: Vector2) -> void:',1)[1].split('func _remember_jump_flick_sample(',1)[0]
assert 'if landing_active:' in land and '_start_omni_step(flick_direction)' in land
step=main.split('func _start_omni_step(flick: Vector2) -> bool:',1)[1].split('func _start_back_step()',1)[0]
assert 'landing_active = false' in step and 'rig.call("finish_jump", false, false)' in step
assert step.index('_spend_energy(') < step.index('landing_active = false')
focus=main.split('func _desired_camera_follow_focus_xz() -> Vector2:',1)[1].split('func _advance_camera_follow_focus(',1)[0]
assert 'return target_xz' in focus
assert 'CAMERA_TARGET_COMPOSITION_SHOULDER_DEGREES * float(camera_composition_side)' in main
assert 'CAMERA_COMPOSITION_SWITCH_SECONDS: float = 0.28' in main
camera=main.split('func _process(delta: float) -> void:',1)[1].split('func _desired_camera_follow_focus_xz()',1)[0]
assert '_fit_boost_frame_analytically(delta)' in camera
assert '_advance_composition_side(delta)' in camera
assert '_enforce_screen_edge(bearing, delta)' not in camera
version=re.search(r'config/name="SERA v(\d+)"',(root/"project.godot").read_text())
assert version and int(version.group(1))>=328
print("PASS v328 lock control layout, system pref, landing STEP, target-centered camera")
