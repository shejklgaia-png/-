#!/usr/bin/env python3
"""v330: restore only v327 camera workflow, preserve v328/v329 input/HUD."""
from pathlib import Path
import re
r=Path(__file__).resolve().parents[1]
main=(r/"scripts/main.gd").read_text(encoding="utf-8")
input=(r/"scripts/sera_input_gestures.gd").read_text(encoding="utf-8")
nexus=(r/"scripts/command_nexus.gd").read_text(encoding="utf-8")
assert 'CAMERA_TARGET_COMPOSITION_SHOULDER_DEGREES' not in main
assert 'CAMERA_PLAYER_SAFE_MARGIN_X' not in main
assert 'camera_composition_side' not in main
assert 'CAMERA_COMBAT_SHOULDER_DEGREES: float = 12.0' in main
assert 'camera_yaw = start_bearing - deg_to_rad(CAMERA_COMBAT_SHOULDER_DEGREES)' in main
focus=main.split("func _desired_camera_follow_focus_xz() -> Vector2:",1)[1].split("func _advance_camera_follow_focus(",1)[0]
assert 'return CAMERA_MATH.desired_follow_focus(' in focus
assert 'player_xz, target_xz, CAMERA_PLAYER_FOCUS_LEAD_METERS)' in focus
camera=main.split("func _process(delta: float) -> void:",1)[1].split("func _desired_camera_follow_focus_xz()",1)[0]
assert camera.count("_enforce_screen_edge(bearing, delta)") == 2
assert 'if boost_edge_frame_guard:' in camera
assert '_fit_boost_frame_analytically(delta)' in camera
assert '_fit_full_frame()' in camera and '_relax_camera_fit_radius(delta)' in camera
assert '_advance_composition_side' not in camera
adaptive=main.split("func _adaptive_camera_yaw(",1)[1].split("func _stable_shoulder_camera_yaw(",1)[0]
assert 'camera_yaw, player_bearing, delta, CAMERA_COMBAT_SHOULDER_DEGREES,' in adaptive
assert 'SCREEN_MARGIN_X, 0.0, 1.0))' in main
assert '(SCREEN_MARGIN_X + extra_margin_ratio)' in main
assert 'return INPUT_GESTURES.combo_kick_side(flick, gesture_screen_forward)' in main
assert 'flick, actor_screen_forward)' in input
assert 'settings.set_value("controls", "auto_lock_enabled", enabled)' in nexus
assert 'if landing_active:' in main
ver=re.search(r'config/name="SERA v(\d+)"',(r/"project.godot").read_text())
assert ver and int(ver.group(1))>=330
print("PASS v330 v327 camera restored; v328/v329 mechanics retained")
