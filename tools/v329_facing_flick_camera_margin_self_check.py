#!/usr/bin/env python3
from pathlib import Path
import re
r=Path(__file__).resolve().parents[1]
m=(r/"scripts/main.gd").read_text()
i=(r/"scripts/sera_input_gestures.gd").read_text()
assert 'gesture_screen_forward = FLICK_DIRECTION_POLICY.projected_forward(camera, player)' in m
assert 'displacement, seconds, gesture_screen_forward,' in m
assert 'displacement, gesture_screen_forward, STEP_FLICK_MAX_HORIZONTAL_RATIO' in m
assert 'release_pos - pointer_origin, gesture_screen_forward)' in m
assert 'return INPUT_GESTURES.combo_kick_side(flick, gesture_screen_forward)' in m
assert 'flick, actor_screen_forward)' in i
assert 'CAMERA_PLAYER_SAFE_MARGIN_X: float = 0.20' in m
assert 'CAMERA_PLAYER_FIT_MARGIN_X: float = 0.22' in m
assert 'CAMERA_PLAYER_FIT_MARGIN_X, 0.0, 1.0))' in m
assert 'CAMERA_PLAYER_SAFE_MARGIN_X + extra_margin_ratio' in m
assert 'return INPUT_GESTURES.step_flick(' in m
assert '_enforce_screen_edge(bearing, delta)' not in m
ver=re.search(r'config/name="SERA v(\d+)"',(r/"project.godot").read_text())
assert ver and int(ver.group(1))>=329
print("PASS v329 projected-forward Bash/kicks, screen STEP, 20% camera band")
