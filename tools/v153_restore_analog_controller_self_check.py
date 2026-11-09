#!/usr/bin/env python3
"""v153: restore v148 origin-anchored analog controller while preserving later rig motion."""
from pathlib import Path
import re, math
p=Path(__file__).resolve().parents[1]
main=(p/"scripts/main.gd").read_text(encoding="utf-8")
ui=(p/"scripts/touch_overlay.gd").read_text(encoding="utf-8")
rig=(p/"scripts/sera_rig.gd").read_text(encoding="utf-8")
project=(p/"project.godot").read_text(encoding="utf-8")
assert re.findall(r'^config/name="([^"]+)"$',project,re.M)==["SERA v156"]
for token in ("const DRAG_RADIUS: float = 168.0",
 "const BOOST_START_RADIUS_RATIO: float = 1.25",
 "const BOOST_EXIT_RADIUS_RATIO: float = 1.10",
 "const BOOST_CONFIRM_SECONDS: float = 0.10",
 "const BOOST_ACCELERATION_SECONDS: float = 0.15",
 "const GROUND_MOVE_SPEED_SCALE: float = 1.25",
 "const MOVEMENT_BOOST_MULTIPLIER: float = 1.5",
 "var delta: Vector2 = (pos - pointer_origin) / DRAG_RADIUS",
 "direction_input = delta.limit_length(1.0)",
 "direction_input = Vector2.ZERO",
 "boost_confirm_elapsed += maxf(delta, 0.0)",
 "boost_speed_multiplier = move_toward",
 'touch_ui.call("show_drag", pointer_origin, pointer_location, DRAG_RADIUS)',
 "player.velocity = world_move * MOVE_SPEED * GROUND_MOVE_SPEED_SCALE * boost_speed_multiplier"):
 assert token in main,token
for token in ("CONTROLLER_BOOST_KNOB_RADIUS_RATIO: float = 1.48",
 "CONTROLLER_BOOST_START_RADIUS_RATIO: float = 1.25",
 "func _draw_radial_controller(",
 "draw_circle(anchor_point, radius",
 "knob_center = anchor_point + finger_vector.normalized()",
 "func set_movement_boost(value: bool)"):
 assert token in ui,token
for forbidden in ("SWIPE_HEADING_WINDOW_MSEC","SWIPE_BOOST_TRAVEL_PIXELS",
 "swipe_heading_target", "_update_swipe_steering(delta)"):
 assert forbidden not in main,forbidden
assert "func set_swipe_motion(" not in ui
assert "VISUAL_TURN_DEADBAND_DEGREES: float = 3.0" in rig
assert "RUN_ANIMATION_SPEED: float = 1.875" in rig
assert math.isclose(3.25*1.25,4.0625)
assert math.isclose(3.25*1.25*1.5,6.09375)
print("v153 v148 analog controller restored: STATIC PASS; Godot/Android runtime NOT TESTED")
