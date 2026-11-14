#!/usr/bin/env python3
"""v334 target-relative camera mirror and same world aim for UI/flick."""
from pathlib import Path
import re
r=Path(__file__).resolve().parents[1]
m=(r/"scripts/main.gd").read_text()
p=(r/"scripts/flick_direction_policy.gd").read_text()
cm=(r/"scripts/sera_camera_math.gd").read_text()
assert 'CAMERA_SIDE_CROSS_HYSTERESIS_RATIO: float = 0.025' in m
assert 'CAMERA_SHOULDER_MIRROR_RATE: float = 7.0' in m
assert 'func screen_side_after_crossing(' in cm
assert 'func smooth_shoulder_mirror(' in cm
assert 'player_screen_side = CAMERA_MATH.screen_side_after_crossing(' in m
assert 'player_x, target_x,' in m
assert 'camera_shoulder_mirror = CAMERA_MATH.smooth_shoulder_mirror(' in m
assert m.count('CAMERA_COMBAT_SHOULDER_DEGREES * camera_shoulder_mirror') == 2
assert m.count('and absf(camera_shoulder_mirror) >= 0.95:') == 2
assert 'func _current_lock_aim_world() -> Vector3:' in m
assert 'var center_world: Vector3 = _current_lock_aim_world()' in m
assert 'func projected_target_line(' in p
assert 'return FLICK_DIRECTION_POLICY.touch_to_target_forward(' in m
assert 'camera, origin_screen, _current_lock_aim_world(),' in m
assert 'var live_locomotion: bool' in m
assert 'if live_locomotion:' in m
assert 'touch_ui.call("set_flick_sector_forward", forward, delta, true)' in m
assert 'return INPUT_GESTURES.combo_kick_side(flick, gesture_screen_forward)' in m
assert 'return INPUT_GESTURES.step_flick(' in m
v=re.search(r'config/name="SERA v(\d+)"',(r/"project.godot").read_text())
assert v and int(v.group(1))>=334
print("PASS v334 target-cross camera mirror + real aim world projection")
