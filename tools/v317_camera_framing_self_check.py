#!/usr/bin/env python3
"""SERA v317 Stage 4: main camera state remains owned, pure equations delegated."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
main = (root/"scripts/main.gd").read_text(encoding="utf-8")
framing = (root/"scripts/sera_camera_framing.gd").read_text(encoding="utf-8")
assert 'const CAMERA_FRAMING = preload("res://scripts/sera_camera_framing.gd")' in main
for wrapper, call in (
    ("func _close_step_target_relative_yaw(", "CAMERA_FRAMING.close_step_target_relative_yaw("),
    ("func _camera_radius_for_safe_point(", "CAMERA_FRAMING.required_radius_for_point("),
):
    assert wrapper in main and call in main, wrapper
for token in (
    "CAMERA_MOVING_YAW_SCALE, STEP_CLOSE_CAMERA_MAX_RELATIVE_DEGREES,",
    "STEP_CLOSE_CAMERA_MAX_TURN_RATE_DEGREES)",
    "tan_h, tan_v, margin_x, margin_top, margin_bottom, camera.near)",
):
    assert token in main, token
for token in (
    "lerp_angle(", "wrapf(", "deg_to_rad(max_relative_degrees)",
    "deg_to_rad(max_turn_degrees_per_second) * delta",
    "tan_h * (1.0 - 2.0 * margin_x)",
    "tan_v * (1.0 - 2.0 * margin_top)",
    "tan_v * (2.0 * margin_bottom - 1.0)",
    "near_plane + 0.005", "(depth + offset.dot(outward)) / radial_scale",
):
    assert token in framing, token
for forbidden in ("get_viewport(", "get_tree(", "var camera_yaw:",
                  "var camera_radius:", "DisplayServer", "FileAccess"):
    assert forbidden not in framing, forbidden
for preserved in ("func _place_camera()", "func _minimum_boost_camera_radius()",
                  "func _enforce_screen_edge(", "func _fit_full_frame()"):
    assert preserved in main, preserved
print("SERA_CAMERA_FRAMING_STATIC_PASS")
