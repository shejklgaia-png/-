#!/usr/bin/env python3
"""Retained v115 controller smoke test, updated for the v149 replacement UI.

The old 125%-radius booster knob was intentionally removed. This now checks
that the replacement HUD offers continuous direction and charge feedback.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
ui = (root/"scripts/touch_overlay.gd").read_text(encoding="utf-8")
main = (root/"scripts/main.gd").read_text(encoding="utf-8")
rig = (root/"scripts/sera_rig.gd").read_text(encoding="utf-8")
project = (root/"project.godot").read_text(encoding="utf-8")
assert 'config/name="SERA v150"' in project
assert 'func _draw_swipe_controller(accent: Color, low: Color) -> void:' in ui
assert 'func set_swipe_motion(pos: Vector2, heading: Vector2,' in ui
assert '_draw_swipe_controller(accent, low)' in ui
assert 'swipe_heading' in ui and 'swipe_boost_progress' in ui
assert 'draw_line(tail, tip, bright, 5.0, true)' in ui
assert 'visual_heading_angle = lerp_angle(' in ui
assert 'draw_circle(tip, 2.5, bright)' in ui
assert 'for n in range(2):' in ui
assert 'BOOST  x1.5' in ui and 'RUN' in ui
assert '_draw_radial_controller(' not in ui
assert 'CONTROLLER_BOOST_START_RADIUS_RATIO' not in ui
assert 'CONTROLLER_BOOST_KNOB_RADIUS_RATIO' not in ui
assert 'mouse_filter = Control.MOUSE_FILTER_IGNORE' in main
assert 'const SWIPE_BOOST_TRAVEL_PIXELS: float = 140.0' in main
assert 'const SWIPE_HEADING_SAMPLE_PIXELS: float = 6.0' in main
assert 'const MOVEMENT_BOOST_MULTIPLIER: float = 1.5' in main
assert 'const BOOST_DIRECTION_BLEND_SECONDS: float = 0.045' in rig
assert 'func _blended_boost_pose(uid: String) -> Dictionary:' in rig
assert 'func set_target_marker_projection(' in ui
assert 'func set_melee_in_range(' in ui
assert 'draw_arc(mark, lock_radius' in ui
print("v115 legacy UI compatibility replaced by v149 swipe HUD: STATIC PASS")
