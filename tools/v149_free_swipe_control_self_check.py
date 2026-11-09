#!/usr/bin/env python3
"""v149 free-swipe steering, BOOST by directional long drag, visual HUD.

Static contract + independent 360-degree and gesture transition simulation.
Full Android input and Godot animation runtime remain unverified.
"""
import math
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
main = (root/"scripts/main.gd").read_text(encoding="utf-8")
ui = (root/"scripts/touch_overlay.gd").read_text(encoding="utf-8")
rig = (root/"scripts/sera_rig.gd").read_text(encoding="utf-8")
project = (root/"project.godot").read_text(encoding="utf-8")
assert re.findall(r'^config/name="([^"]+)"$',project,re.M) == ["SERA v152"]
assert (root/"README_v149_ja.md").exists()

def part(source, start, end):
    return source.split("func "+start, 1)[1].split("func "+end, 1)[0]

drag = part(main,"_change_drag(pos: Vector2) -> void:",
            "_update_boost_gesture(")
gate = part(main,"_update_boost_gesture(_delta: float) -> void:",
            "_end_drag(")
physics = part(main,"_physics_process(delta: float) -> void:",
               "_close_step_target_relative_yaw(")
touch = part(main,"_input(event: InputEvent) -> void:",
             "_guard_can_start()")
boost_visual = part(ui,"_draw_swipe_controller(accent: Color, low: Color) -> void:",
                    "_UNUSED_SENTINEL") if "func _UNUSED_SENTINEL" in ui else ui.split(
                        "func _draw_swipe_controller(accent: Color, low: Color) -> void:",1)[1]

assert "const SWIPE_HEADING_SAMPLE_PIXELS: float = 12.0" in main
assert "const SWIPE_HEADING_WINDOW_MSEC: int = 80" in main
assert "const SWIPE_HEADING_DEADBAND_DEGREES: float = 12.0" in main
assert "const SWIPE_BOOST_TRAVEL_PIXELS: float = 140.0" in main
assert "const SWIPE_BOOST_RESET_DOT: float = 0.65" in main
assert "var segment: Vector2 = pos - pointer_location" in drag
assert "swipe_heading_samples.append(" in drag
assert "recent_displacement: Vector2" in drag
assert "swipe_heading_target = next_heading" in drag
assert "next_heading.dot(swipe_heading_target) < SWIPE_BOOST_RESET_DOT" in drag
assert "direction_input = next_heading" in drag
assert "swipe_boost_travel = maxf(swipe_boost_travel, forward_travel)" in drag
assert "func _update_swipe_steering(delta: float) -> void:" in main
assert "swipe_boost_travel >= SWIPE_BOOST_TRAVEL_PIXELS" in drag
assert "boost_has_activated_this_gesture = true" in drag
assert "set_swipe_motion" in drag
assert "damage_reaction_active" in gate and "movement_boost_active = false" in gate
assert "direction_input = Vector2.ZERO" in main
assert "_classify_step_flick(" in main and "_start_attack()" in main
assert "_update_guard_hold()" in physics
assert "event is InputEventScreenDrag" in touch
assert "rig.call(\"set_moving\", running, movement_boost_active, local_run_direction)" in physics
assert "MOVEMENT_BOOST_MULTIPLIER if movement_boost_active else 1.0" in physics
assert "boost_speed_multiplier" not in main
assert "BOOST_START_RADIUS_RATIO" not in main
assert "direction_input = delta.limit_length(1.0)" not in main
assert "const RUN_DIRECTION_BLEND_SECONDS: float = 0.055" in rig
assert "const BOOST_DIRECTION_BLEND_SECONDS: float = 0.045" in rig
assert "const RUN_ROOT_TURN_SPEED_DEGREES: float = 1440.0" in rig

assert "func set_swipe_motion(pos: Vector2, heading: Vector2," in ui
assert "draw_line(tail, tip, bright, 5.0, true)" in boost_visual
assert "draw_polyline(PackedVector2Array([" in boost_visual
assert "draw_circle(tip, 2.5, bright)" in boost_visual
assert "visual_heading_angle = lerp_angle(" in ui
assert "swipe_boost_progress" in boost_visual
assert "draw_arc(center, 35.0" in boost_visual
assert '"BOOST  x1.5"' in boost_visual
assert "_draw_radial_controller" not in ui
assert "CONTROLLER_BOOST_KNOB_RADIUS_RATIO" not in ui
assert 'draw_arc(mark, lock_radius' in ui # Existing lock-on ring preserved
assert "OPERATION_ZONE_TOP_RATIO: float = 0.75" in ui

# Historical 360° direction coverage remains valid: the new physical-thumb
# threshold changes the minimum distance, not the set of allowed headings.
for degrees in range(0, 360, 5):
    angle = math.radians(degrees)
    dx, dy = 16.0 * math.cos(angle), 16.0 * math.sin(angle)
    travel = math.hypot(dx, dy)
    assert travel >= 12.0
    direction = (dx / travel, dy / travel)
    assert math.isclose(math.hypot(*direction), 1.0, abs_tol=1e-12)
assert "swipe_boost_travel >= SWIPE_BOOST_TRAVEL_PIXELS" in drag
assert "boost_has_activated_this_gesture = true" in drag
print("v149 360° input coverage, fixed RUN/BOOST, current swipe HUD: STATIC+MATH PASS")
print("Current v152 human-thumb sensitivity scenarios: see v152 self-check.")
