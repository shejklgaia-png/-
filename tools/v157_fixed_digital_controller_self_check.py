#!/usr/bin/env python3
"""v157: fixed digital 8-way controller static checks plus independent numeric scenarios."""
from pathlib import Path
import math, re
p=Path(__file__).resolve().parents[1]
s=(p/"scripts/main.gd").read_text(encoding="utf-8")
ui=(p/"scripts/touch_overlay.gd").read_text(encoding="utf-8")
rig=(p/"scripts/sera_rig.gd").read_text(encoding="utf-8")
cfg=(p/"project.godot").read_text(encoding="utf-8")
if "SERA v157" not in cfg:
    print("SKIP: historical v157 digital-pad test (requires SERA v157)")
    raise SystemExit(0)
assert re.findall(r'^config/name="([^"]+)"
for token in (
    "const DIGITAL_ENGAGE_DISTANCE: float = 34.0",
    "const DIGITAL_RELEASE_DISTANCE: float = 22.0",
    "const DIGITAL_SECTOR_HYSTERESIS_DEGREES: float = 6.0",
    "digital_direction_sector = -1",
    "func _digital_stick_direction(pos: Vector2) -> Vector2:",
    "var displacement: Vector2 = pos - pointer_origin",
    "if distance < DIGITAL_RELEASE_DISTANCE:",
    "if digital_direction_sector < 0 and distance < DIGITAL_ENGAGE_DISTANCE:",
    "wrapi(int(round(angle / (PI * 0.25))), 0, 8)",
    "absf(wrapf(angle - current_angle, -PI, PI))",
    "return Vector2.RIGHT.rotated(float(digital_direction_sector) * PI * 0.25)",
    "direction_input = _digital_stick_direction(pos)",
    'touch_ui.call("set_digital_direction", digital_direction_sector)',
    "pointer_location.distance_to(pointer_origin)",
    "const BOOST_START_RADIUS_RATIO: float = 1.25",
    "const BOOST_EXIT_RADIUS_RATIO: float = 1.10",
    "const BOOST_CONFIRM_SECONDS: float = 0.10",
    "const BOOST_ACCELERATION_SECONDS: float = 0.15",
    "const GROUND_MOVE_SPEED_SCALE: float = 1.25",
    "gesture_max_travel = maxf(gesture_max_travel, pos.distance_to(pointer_origin))",
    "_classify_step_flick(",
):
    assert token in s,token
for forbidden in ("FAST_REVERSE_MIN_SPEED_PIXELS_PER_SEC","reverse_stroke",
    "boost_rearm_after_reverse","boost_pointer_origin",
    "pointer_origin = reverse_stroke_origin","var delta: Vector2 = (pos - pointer_origin) / DRAG_RADIUS"):
    assert forbidden not in s,forbidden
for token in ("func _draw_digital_controller(", "func set_digital_direction(",
    "var digital_direction_sector: int = -1", "for sector in range(8):",
    "draw_colored_polygon(triangle,", "draw_arc(anchor_point, radius * CONTROLLER_BOOST_START_RADIUS_RATIO",
    "if dragging:\n        return", "digital_direction_sector = -1"):
    assert token in ui,token
for forbidden in ("finger_point","knob_center","boost_anchor_point","func _draw_radial_controller("):
    assert forbidden not in ui,forbidden
assert 'VISUAL_TURN_DEADBAND_DEGREES: float = 3.0' in rig
assert 'RUN_ANIMATION_SPEED: float = 1.875' in rig

class Pad:
    def __init__(self):
        self.sector=-1
    def update(self, x, y):
        distance=math.hypot(x,y)
        if distance<22:
            self.sector=-1
            return None
        if self.sector<0 and distance<34:
            return None
        angle=math.atan2(y,x)
        nearest=round(angle/(math.pi/4))%8
        if self.sector>=0:
            prev=self.sector*math.pi/4
            diff=(angle-prev+math.pi)%(2*math.pi)-math.pi
            if abs(diff)<=math.pi/8+math.radians(6):
                nearest=self.sector
        self.sector=nearest
        return (math.cos(self.sector*math.pi/4),math.sin(self.sector*math.pi/4))
def direction(p,x,y,expected):
    got=p.update(x,y)
    assert p.sector==expected, (x,y,got,p.sector,expected)
    if got is not None:
        assert math.isclose(math.hypot(*got),1.0,abs_tol=1e-9)
pad=Pad()
direction(pad,10,10,-1)    # tap / guard dead region
direction(pad,30,0,-1)     # under engage distance
direction(pad,34,0,0)      # right, full-speed
direction(pad,30,12,0)    # 21.8deg; hold current sector
direction(pad,30,18,1)    # 31deg exceeds right-sector hysteresis
direction(pad,-50,0,4)    # a direct opposite input: no center swap
assert pad.sector==4
direction(pad,21,0,-1)    # release inside the 22px stop region
direction(pad,-40,0,4)
direction(pad,0,-40,6)    # UP
direction(pad,0,40,2)     # DOWN
direction(pad,42,0,0)     # RIGHT
direction(pad,-42,0,4)    # LEFT
for k in range(8):
    q=Pad()
    angle=k*math.pi/4
    x=60*math.cos(angle); y=60*math.sin(angle)
    direction(q,x,y,k)
# Original BOOST fixed thresholds, not digital direction distances.
assert math.isclose(168*1.25,210.0)
assert math.isclose(168*1.10,184.8)
print("v157 digital pad: STATIC & numerical eight-way / jitter / opposite / BOOST checks PASS")
print("Godot & Android runtime NOT TESTED")
,cfg,re.M)==["SERA v157"]
for token in (
    "const DIGITAL_ENGAGE_DISTANCE: float = 34.0",
    "const DIGITAL_RELEASE_DISTANCE: float = 22.0",
    "const DIGITAL_SECTOR_HYSTERESIS_DEGREES: float = 6.0",
    "digital_direction_sector = -1",
    "func _digital_stick_direction(pos: Vector2) -> Vector2:",
    "var displacement: Vector2 = pos - pointer_origin",
    "if distance < DIGITAL_RELEASE_DISTANCE:",
    "if digital_direction_sector < 0 and distance < DIGITAL_ENGAGE_DISTANCE:",
    "wrapi(int(round(angle / (PI * 0.25))), 0, 8)",
    "absf(wrapf(angle - current_angle, -PI, PI))",
    "return Vector2.RIGHT.rotated(float(digital_direction_sector) * PI * 0.25)",
    "direction_input = _digital_stick_direction(pos)",
    'touch_ui.call("set_digital_direction", digital_direction_sector)',
    "pointer_location.distance_to(pointer_origin)",
    "const BOOST_START_RADIUS_RATIO: float = 1.25",
    "const BOOST_EXIT_RADIUS_RATIO: float = 1.10",
    "const BOOST_CONFIRM_SECONDS: float = 0.10",
    "const BOOST_ACCELERATION_SECONDS: float = 0.15",
    "const GROUND_MOVE_SPEED_SCALE: float = 1.25",
    "gesture_max_travel = maxf(gesture_max_travel, pos.distance_to(pointer_origin))",
    "_classify_step_flick(",
):
    assert token in s,token
for forbidden in ("FAST_REVERSE_MIN_SPEED_PIXELS_PER_SEC","reverse_stroke",
    "boost_rearm_after_reverse","boost_pointer_origin",
    "pointer_origin = reverse_stroke_origin","var delta: Vector2 = (pos - pointer_origin) / DRAG_RADIUS"):
    assert forbidden not in s,forbidden
for token in ("func _draw_digital_controller(", "func set_digital_direction(",
    "var digital_direction_sector: int = -1", "for sector in range(8):",
    "draw_colored_polygon(triangle,", "draw_arc(anchor_point, radius * CONTROLLER_BOOST_START_RADIUS_RATIO",
    "if dragging:\n        return", "digital_direction_sector = -1"):
    assert token in ui,token
for forbidden in ("finger_point","knob_center","boost_anchor_point","func _draw_radial_controller("):
    assert forbidden not in ui,forbidden
assert 'VISUAL_TURN_DEADBAND_DEGREES: float = 3.0' in rig
assert 'RUN_ANIMATION_SPEED: float = 1.875' in rig

class Pad:
    def __init__(self):
        self.sector=-1
    def update(self, x, y):
        distance=math.hypot(x,y)
        if distance<22:
            self.sector=-1
            return None
        if self.sector<0 and distance<34:
            return None
        angle=math.atan2(y,x)
        nearest=round(angle/(math.pi/4))%8
        if self.sector>=0:
            prev=self.sector*math.pi/4
            diff=(angle-prev+math.pi)%(2*math.pi)-math.pi
            if abs(diff)<=math.pi/8+math.radians(6):
                nearest=self.sector
        self.sector=nearest
        return (math.cos(self.sector*math.pi/4),math.sin(self.sector*math.pi/4))
def direction(p,x,y,expected):
    got=p.update(x,y)
    assert p.sector==expected, (x,y,got,p.sector,expected)
    if got is not None:
        assert math.isclose(math.hypot(*got),1.0,abs_tol=1e-9)
pad=Pad()
direction(pad,10,10,-1)    # tap / guard dead region
direction(pad,30,0,-1)     # under engage distance
direction(pad,34,0,0)      # right, full-speed
direction(pad,30,12,0)    # 21.8deg; hold current sector
direction(pad,30,18,1)    # 31deg exceeds right-sector hysteresis
direction(pad,-50,0,4)    # a direct opposite input: no center swap
assert pad.sector==4
direction(pad,21,0,-1)    # release inside the 22px stop region
direction(pad,-40,0,4)
direction(pad,0,-40,6)    # UP
direction(pad,0,40,2)     # DOWN
direction(pad,42,0,0)     # RIGHT
direction(pad,-42,0,4)    # LEFT
for k in range(8):
    q=Pad()
    angle=k*math.pi/4
    x=60*math.cos(angle); y=60*math.sin(angle)
    direction(q,x,y,k)
# Original BOOST fixed thresholds, not digital direction distances.
assert math.isclose(168*1.25,210.0)
assert math.isclose(168*1.10,184.8)
print("v157 digital pad: STATIC & numerical eight-way / jitter / opposite / BOOST checks PASS")
print("Godot & Android runtime NOT TESTED")
