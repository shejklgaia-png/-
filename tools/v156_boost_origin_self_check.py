#!/usr/bin/env python3
"""v156: preserved original BOOST zone after instant steering reversal."""
from pathlib import Path
import math,re
root=Path(__file__).resolve().parents[1]
main=(root/"scripts/main.gd").read_text(encoding="utf-8")
ui=(root/"scripts/touch_overlay.gd").read_text(encoding="utf-8")
rig=(root/"scripts/sera_rig.gd").read_text(encoding="utf-8")
project=(root/"project.godot").read_text(encoding="utf-8")
assert re.findall(r'^config/name="([^"]+)"$',project,re.M)==["SERA v156"]
for term in ("var boost_pointer_origin: Vector2 = Vector2.ZERO",
    "boost_pointer_origin = pos","boost_rearm_after_reverse = true",
    "pointer_origin = reverse_stroke_origin",
    "pointer_location.distance_to(boost_pointer_origin)",
    "if boost_rearm_after_reverse:",
    "if finger_distance >= DRAG_RADIUS * BOOST_EXIT_RADIUS_RATIO:",
    "boost_confirm_elapsed = 0.0",
    "FAST_REVERSE_MIN_SPEED_PIXELS_PER_SEC: float = 800.0",
    "FAST_REVERSE_OPPOSITE_DOT: float = -0.80",
    "const BOOST_CONFIRM_SECONDS: float = 0.10",
    "const BOOST_ACCELERATION_SECONDS: float = 0.15"):
    assert term in main,term
boost_body=main.split("func _update_boost_gesture(",1)[1].split("func _end_drag(",1)[0]
assert "pointer_location.distance_to(pointer_origin)" not in boost_body
assert "boost_anchor_point = origin" in ui
assert "draw_arc(boost_anchor_point, radius * CONTROLLER_BOOST_START_RADIUS_RATIO" in ui
assert "draw_circle(anchor_point, radius" in ui
assert "VISUAL_TURN_DEADBAND_DEGREES: float = 3.0" in rig
assert math.isclose(168*1.25,210)
assert math.isclose(168*1.10,184.8)
class Gesture:
    def __init__(self):
        self.original=0.; self.stick=0.; self.active=False
        self.rearm=False; self.confirm=0.
    def reverse(self,origin):
        self.stick=origin; self.active=False; self.rearm=True; self.confirm=0.
    def tick(self,x,dt):
        dist=abs(x-self.original)
        if self.rearm:
            self.confirm=0.
            if dist>=168*1.10:return self.active
            self.rearm=False
        if self.active:
            if dist<168*1.10:
                self.active=False; self.confirm=0.
        elif dist>=168*1.25:
            self.confirm+=dt
            if self.confirm>=0.10:self.active=True
        else:self.confirm=0.
        return self.active
b=Gesture()
for i in range(7):b.tick(250,.016)
assert b.active
b.reverse(250)
assert not b.active and b.stick==250 and b.original==0
for i in range(20):assert not b.tick(225,.016)
assert b.rearm
assert not b.tick(180,.016) and not b.rearm
for i in range(20):assert not b.tick(-200,.016)
for i in range(6):assert not b.tick(-220,.016)
assert b.tick(-220,.016)
c=Gesture()
c.reverse(100)
assert not c.tick(60,.016) and not c.rearm
for i in range(6):assert not c.tick(-210,.016)
assert c.tick(-210,.016)
c.reverse(-210); c.reverse(-260)
assert c.original==0 and not c.active and c.rearm
d=Gesture()
for i in range(100): assert not d.tick(209.9,.016)
for i in range(6):assert not d.tick(210,.016)
assert d.tick(210,.016)
print("v156 fixed BOOST origin / rearm / threshold checks: PASS")
print("Godot and Android real-device: NOT TESTED")
