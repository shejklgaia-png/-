#!/usr/bin/env python3
"""SERA v115: BOOST displayed thumb stays outside the 125% guide (static and numeric)."""
from pathlib import Path
import math
import re

root = Path(__file__).resolve().parents[1]
ui = (root / "scripts/touch_overlay.gd").read_text(encoding="utf-8")
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
rig = (root / "scripts/sera_rig.gd").read_text(encoding="utf-8")

def constant(src: str, name: str) -> float:
    value = re.search(r"const " + re.escape(name) + r": float = ([0-9.]+)", src)
    assert value is not None, name
    return float(value.group(1))

radius = constant(main, "DRAG_RADIUS")
guide = constant(ui, "CONTROLLER_BOOST_START_RADIUS_RATIO")
knob = constant(ui, "CONTROLLER_BOOST_KNOB_RADIUS_RATIO")
dot = constant(ui, "CONTROLLER_FINGER_DOT_RADIUS")
assert radius == 168.0
assert guide == constant(main, "BOOST_START_RADIUS_RATIO") == 1.25
assert knob == 1.48
assert dot == 29.0
assert (knob - guide) * radius > dot + 3.0  # clear the 3px active guide.
assert "var knob_center: Vector2 = anchor_point + finger_vector.limit_length(radius)" in ui
assert "if movement_boost_active and finger_vector.length_squared() > 0.000001:" in ui
assert "knob_center = anchor_point + finger_vector.normalized() * (radius * CONTROLLER_BOOST_KNOB_RADIUS_RATIO)" in ui
assert "if finger_vector.length_squared() > radius * radius or movement_boost_active:" in ui
assert "var guide_color: Color = accent if movement_boost_active else" in ui
assert "var guide_width: float = 3.0 if movement_boost_active else 2.0" in ui
assert 'func set_movement_boost(value: bool) -> void:' in ui
assert "movement_boost_active = value\n    queue_redraw()" in ui
assert "dragging = false\n    movement_boost_active = false" in ui
assert 'const OPERATION_ZONE_TOP_RATIO: float = 0.75' in ui
assert 'CONTROLLER_CHEVRON_NEAR_RATIO: float = 1.13' in ui
assert 'CONTROLLER_CHEVRON_FAR_RATIO: float = 1.27' in ui
assert 'config/name="SERA v' in project
assert "const BOOST_DIRECTION_BLEND_SECONDS: float = 0.06" in rig
assert "func _blended_boost_pose(uid: String) -> Dictionary:" in rig

# Input semantics and BOOST speed/threshold logic are unchanged.
assert constant(main, "BOOST_EXIT_RADIUS_RATIO") == 1.10
assert constant(main, "BOOST_CONFIRM_SECONDS") == 0.10
assert constant(main, "BOOST_ACCELERATION_SECONDS") == 0.15
assert constant(main, "MOVEMENT_BOOST_MULTIPLIER") == 1.5
assert "finger_distance < DRAG_RADIUS * BOOST_EXIT_RADIUS_RATIO" in main
assert "finger_distance >= DRAG_RADIUS * BOOST_START_RADIUS_RATIO" in main
assert "boost_confirm_elapsed += maxf(delta, 0.0)" in main
assert "direction_input = delta.limit_length(1.0)" in main
assert 'touch_ui.call("set_movement_boost", true)' in main
assert 'touch_ui.call("set_movement_boost", false)' in main
assert 'touch_ui.call("show_drag", pointer_origin, pointer_location, DRAG_RADIUS)' in main

# The BOOST knob is always outside the guide, even in 110%-125% hysteresis,
# where the real finger is between the two thresholds.
for degrees in range(0, 360, 15):
    d = math.radians(degrees)
    for finger_ratio in (1.10, 1.12, 1.24, 1.25, 1.5, 2.0):
        dx, dy = math.cos(d) * finger_ratio, math.sin(d) * finger_ratio
        distance = math.hypot(dx, dy)
        boost_center = knob * radius * math.hypot(dx / distance, dy / distance)
        run_center = min(distance, 1.0) * radius
        assert abs(boost_center - 248.64) < 1e-8
        assert boost_center - dot > guide * radius + 3.0
        assert run_center <= radius
print("v115 BOOST visible knob / guide / legacy input invariants: PASS")
