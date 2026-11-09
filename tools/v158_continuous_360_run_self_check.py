#!/usr/bin/env python3
"""v158: continuous 360-degree fixed-center RUN and unchanged BOOST threshold."""
from pathlib import Path
import math,re
p=Path(__file__).resolve().parents[1]
main=(p/"scripts/main.gd").read_text(encoding="utf-8")
ui=(p/"scripts/touch_overlay.gd").read_text(encoding="utf-8")
rig=(p/"scripts/sera_rig.gd").read_text(encoding="utf-8")
cfg=(p/"project.godot").read_text(encoding="utf-8")
assert re.findall(r'^config/name="([^"]+)"$',cfg,re.M)==["SERA v158"]
for token in (
    "const RUN_CONTROL_RADIUS: float = 112.0",
    "const RUN_INPUT_DEADZONE_PIXELS: float = 18.0",
    "const DRAG_RADIUS: float = 168.0",
    "func _analog_stick_direction(pos: Vector2) -> Vector2:",
    "var displacement: Vector2 = pos - pointer_origin",
    "if distance <= RUN_INPUT_DEADZONE_PIXELS:",
    "(RUN_CONTROL_RADIUS - RUN_INPUT_DEADZONE_PIXELS), 0.0, 1.0)",
    "return displacement / distance * strength",
    "direction_input = _analog_stick_direction(pos)",
    'touch_ui.call("set_analog_direction", direction_input)',
    "pointer_location.distance_to(pointer_origin)",
    "const BOOST_START_RADIUS_RATIO: float = 1.25",
    "const BOOST_EXIT_RADIUS_RATIO: float = 1.10",
    "const BOOST_CONFIRM_SECONDS: float = 0.10",
    "const BOOST_ACCELERATION_SECONDS: float = 0.15",
    "const GROUND_MOVE_SPEED_SCALE: float = 1.25",
):
    assert token in main,token
for forbidden in ("digital_direction_sector","_digital_stick_direction(",
    "DIGITAL_SECTOR_HYSTERESIS_DEGREES","reverse_stroke","boost_rearm_after_reverse"):
    assert forbidden not in main,forbidden
for token in (
    "const CONTROLLER_RUN_RADIUS: float = 112.0",
    "var boost_base_radius: float = 168.0",
    "radius = CONTROLLER_RUN_RADIUS",
    "boost_base_radius = max_radius",
    "func set_analog_direction(value: Vector2) -> void:",
    "func _draw_analog_controller(",
    "var angle: float = heading.angle()",
    "draw_arc(anchor_point, radius * 0.88,",
    "draw_arc(anchor_point, boost_base_radius * CONTROLLER_BOOST_START_RADIUS_RATIO,",
    "if dragging:\n        return",
):
    assert token in ui,token
for forbidden in ("digital_direction_sector","finger_point","knob_center",
    "_draw_digital_controller(","for sector in range(8):"):
    assert forbidden not in ui,forbidden
assert 'VISUAL_TURN_DEADBAND_DEGREES: float = 3.0' in rig
assert math.isclose(168*1.25,210)
assert math.isclose(168*1.10,184.8)
def analog(x,y):
    d=math.hypot(x,y)
    if d<=18:return (0.,0.)
    strength=min(1.,max(0.,(d-18)/94))
    return (x/d*strength,y/d*strength)
for angle in (0,1,12,22.5,23,44,45,46,67,90,135,180,225,270,315,359):
    theta=math.radians(angle)
    direction=analog(112*math.cos(theta),112*math.sin(theta))
    assert math.isclose(math.hypot(*direction),1.0,abs_tol=1e-8)
    assert abs(math.atan2(direction[1],direction[0])-theta)<1e-7 or (
        math.isclose(math.atan2(direction[1],direction[0]),theta-2*math.pi,abs_tol=1e-7))
assert analog(18,0)==(0.,0.)
assert math.isclose(math.hypot(*analog(65,0)),.5,abs_tol=1e-8)
assert math.isclose(math.hypot(*analog(1000,0)),1.,abs_tol=1e-8)
# Continuous headings on either side of former 22.5 degree sector boundary.
a=analog(100*math.cos(math.radians(22.49)),100*math.sin(math.radians(22.49)))
b=analog(100*math.cos(math.radians(22.51)),100*math.sin(math.radians(22.51)))
assert math.dist(a,b)<.001
print("v158 continuous 360-degree RUN / compact fixed rim / unchanged BOOST: STATIC + NUMERIC PASS")
print("Godot / Android runtime: NOT TESTED")
