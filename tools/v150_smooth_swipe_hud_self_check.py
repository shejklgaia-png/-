#!/usr/bin/env python3
"""v150: frame-smoothed visual-only controller; steering unchanged."""
from math import exp, pi
from pathlib import Path
import re

root=Path(__file__).resolve().parents[1]
ui=(root/"scripts/touch_overlay.gd").read_text(encoding="utf-8")
main=(root/"scripts/main.gd").read_text(encoding="utf-8")
rig=(root/"scripts/sera_rig.gd").read_text(encoding="utf-8")
project=(root/"project.godot").read_text(encoding="utf-8")
assert re.findall(r'^config/name="([^"]+)"$',project,re.M)==["SERA v151"]

def region(start, end):
    return ui.split("func "+start,1)[1].split("func "+end,1)[0]
process=region("_process(delta: float) -> void:", "show_drag(")
start=region("show_drag(origin: Vector2, pos: Vector2, max_radius: float) -> void:", "hide_drag(")
end=region("hide_drag() -> void:", "set_swipe_motion(")
input_handler=region("set_swipe_motion(pos: Vector2, heading: Vector2,", "set_movement_boost(")
draw=ui.split("func _draw_swipe_controller(accent: Color, low: Color) -> void:",1)[1]

assert "const SWIPE_POSITION_FOLLOW_SECONDS: float = 0.040" in ui
assert "const SWIPE_HEADING_FOLLOW_SECONDS: float = 0.052" in ui
assert "const SWIPE_CHARGE_FOLLOW_SECONDS: float = 0.070" in ui
assert "var visual_finger_point: Vector2 = Vector2.ZERO" in ui
assert "var visual_heading_angle: float = 0.0" in ui
assert "var visual_boost_progress: float = 0.0" in ui
assert "visual_finger_point = visual_finger_point.lerp(finger_point, position_alpha)" in process
assert "visual_heading_angle = lerp_angle(" in process
assert "visual_boost_progress = lerpf(" in process
assert "1.0 - exp(-step / SWIPE_POSITION_FOLLOW_SECONDS)" in process
assert "1.0 - exp(-step / SWIPE_HEADING_FOLLOW_SECONDS)" in process
assert "1.0 - exp(-step / SWIPE_CHARGE_FOLLOW_SECONDS)" in process
assert "set_process(true)" in start
assert "visual_heading_initialized = false" in start
assert "visual_finger_point = pos" in start
assert "visual_heading_initialized = false" in end
assert "set_process(false)" in end
assert "visual_heading_angle = swipe_heading.angle()" in input_handler
assert "visual_heading_initialized = true" in input_handler
assert "var center := Vector2(clampf(visual_finger_point.x" in draw
assert "visual_boost_progress" in draw
assert "var direction := Vector2(cos(visual_heading_angle), sin(visual_heading_angle))" in draw
assert "draw_colored_polygon(" not in draw
assert "draw_polyline(PackedVector2Array([" in draw
assert "draw_circle(tip, 2.5, bright)" in draw
assert "if dragging:" in process
assert "if not dragging and lock_anim_elapsed >= LOCK_SPIN_DURATION:" in process
assert "lock_anim_elapsed = minf(" in process
assert "draw_arc(mark, lock_radius" in ui
assert "OPERATION_ZONE_TOP_RATIO: float = 0.75" in ui
assert "const SWIPE_HEADING_SAMPLE_PIXELS: float = 6.0" in main
assert "const SWIPE_BOOST_TRAVEL_PIXELS: float = 140.0" in main
assert "direction_input = next_heading" in main
assert "MOVEMENT_BOOST_MULTIPLIER if movement_boost_active else 1.0" in main
assert "const RUN_DIRECTION_BLEND_SECONDS: float = 0.055" in rig

# Exponential smoothing reaches the same result at 30, 60, 120 FPS.
for time_constant in (0.040,0.052,0.070):
    results=[]
    for fps in (30,60,120):
        state=0.0
        for _ in range(fps):
            alpha=1.0-exp(-(1.0/fps)/time_constant)
            state+=(1.0-state)*alpha
        results.append(state)
    assert max(results)-min(results) < 1.e-12

# 359° -> 1° should rotate 2°, not reverse around by 358°.
a=359*pi/180
b=1*pi/180
difference=(b-a+pi)%(2*pi)-pi
assert abs(difference-2*pi/180)<1.e-12
print("v150 HUD rendering interpolation, animation lifecycle and input isolation: STATIC+MATH PASS")
print("Godot/Xperia visual interpolation: NOT TESTED")
