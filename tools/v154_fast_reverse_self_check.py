#!/usr/bin/env python3
"""v154: static assertions and independent quick reverse movement scenarios."""
import math
import re
from pathlib import Path
p=Path(__file__).resolve().parents[1]
main=(p/"scripts/main.gd").read_text(encoding="utf-8")
ui=(p/"scripts/touch_overlay.gd").read_text(encoding="utf-8")
rig=(p/"scripts/sera_rig.gd").read_text(encoding="utf-8")
cfg=(p/"project.godot").read_text(encoding="utf-8")
if "SERA v156" not in cfg:
    print("SKIP: historical v154 controller test (requires SERA v156)")
    raise SystemExit(0)
assert re.findall(r'^config/name="([^"]+)"
for token in ("FAST_REVERSE_MIN_RADIAL_RATIO: float = 0.25",
              "FAST_REVERSE_MIN_TRAVEL_PIXELS: float = 32.0",
              "FAST_REVERSE_MIN_SPEED_PIXELS_PER_SEC: float = 800.0",
              "FAST_REVERSE_MAX_STROKE_MSEC: int = 120",
              "FAST_REVERSE_OPPOSITE_DOT: float = -0.80",
              "reverse_stroke_start_ms = reverse_last_event_ms",
              "pointer_origin = reverse_stroke_origin",
              "gesture_touch_origin = pos",
              "gesture_max_travel = maxf(gesture_max_travel, pos.distance_to(gesture_touch_origin))",
              "fast_reversed_during_gesture",
              "direction_input = delta.limit_length(1.0)",
              "const BOOST_START_RADIUS_RATIO: float = 1.25",
              "const BOOST_EXIT_RADIUS_RATIO: float = 1.10",
              "const BOOST_CONFIRM_SECONDS: float = 0.10",
              "const BOOST_ACCELERATION_SECONDS: float = 0.15",
              "boost_speed_multiplier = move_toward"):
    assert token in main,token
assert "func _draw_radial_controller(" in ui
assert "CONTROLLER_BOOST_KNOB_RADIUS_RATIO: float = 1.48" in ui
assert "VISUAL_TURN_DEADBAND_DEGREES: float = 3.0" in rig
assert (p/"README_v154_ja.md").exists()

# Independent numerical reproduction of the gesture qualification rules.
def recognize(previous_origin, samples):
    pivot=previous_origin
    prior=(0.,0.)
    previous_t=0
    stroke=None
    start_t=0
    qualified=False
    for (x,y,t) in samples:
        current=(x,y)
        seg=(x-prior[0],y-prior[1])
        radial=(prior[0]-pivot[0],prior[1]-pivot[1])
        d=math.hypot(*seg)
        r=math.hypot(*radial)
        if d>=2 and r>=168*.25:
            hd=(radial[0]/r,radial[1]/r)
            if seg[0]*hd[0]+seg[1]*hd[1] <= -.8*d:
                if stroke is None or t-start_t>120:
                    stroke=prior
                    start_t=previous_t
                net=(x-stroke[0],y-stroke[1])
                n=math.hypot(*net)
                duration=max(1,t-start_t)
                if (n>=32 and duration<=120 and n*1000/duration>=800
                    and net[0]*hd[0]+net[1]*hd[1]<=-.8*n
                    and (x-pivot[0])*hd[0]+(y-pivot[1])*hd[1]>0):
                    pivot=stroke
                    qualified=True
                    stroke=None
            else:
                stroke=None
        elif d>=2:
            stroke=None
        prior=current
        previous_t=t
    return qualified,pivot,(prior[0]-pivot[0],prior[1]-pivot[1])

fast=recognize((0,0),[(100,0,250),(85,0,266),(70,0,282),(60,0,298)])
assert fast[0] and fast[1]==(100,0) and fast[2][0]<0,fast
slow=recognize((0,0),[(100,0,250),(88,0,326),(76,0,402),(64,0,478),(52,0,554)])
assert not slow[0] and slow[2][0]>0,slow
side=recognize((0,0),[(100,0,250),(99,14,266),(95,26,282),(94,40,298)])
assert not side[0],side
tiny=recognize((0,0),[(100,0,250),(97,0,266),(101,0,282),(98,0,298)])
assert not tiny[0],tiny
boost=recognize((0,0),[(220,0,250),(207,0,266),(194,0,282),(181,0,298)])
assert boost[0] and math.hypot(*boost[2])<168*1.10,boost
print("v154 static and 5 analog recognition cases PASS; Godot/Android NOT TESTED")
,cfg,re.M)==["SERA v156"]
for token in ("FAST_REVERSE_MIN_RADIAL_RATIO: float = 0.25",
              "FAST_REVERSE_MIN_TRAVEL_PIXELS: float = 32.0",
              "FAST_REVERSE_MIN_SPEED_PIXELS_PER_SEC: float = 800.0",
              "FAST_REVERSE_MAX_STROKE_MSEC: int = 120",
              "FAST_REVERSE_OPPOSITE_DOT: float = -0.80",
              "reverse_stroke_start_ms = reverse_last_event_ms",
              "pointer_origin = reverse_stroke_origin",
              "gesture_touch_origin = pos",
              "gesture_max_travel = maxf(gesture_max_travel, pos.distance_to(gesture_touch_origin))",
              "fast_reversed_during_gesture",
              "direction_input = delta.limit_length(1.0)",
              "const BOOST_START_RADIUS_RATIO: float = 1.25",
              "const BOOST_EXIT_RADIUS_RATIO: float = 1.10",
              "const BOOST_CONFIRM_SECONDS: float = 0.10",
              "const BOOST_ACCELERATION_SECONDS: float = 0.15",
              "boost_speed_multiplier = move_toward"):
    assert token in main,token
assert "func _draw_radial_controller(" in ui
assert "CONTROLLER_BOOST_KNOB_RADIUS_RATIO: float = 1.48" in ui
assert "VISUAL_TURN_DEADBAND_DEGREES: float = 3.0" in rig
assert (p/"README_v154_ja.md").exists()

# Independent numerical reproduction of the gesture qualification rules.
def recognize(previous_origin, samples):
    pivot=previous_origin
    prior=(0.,0.)
    previous_t=0
    stroke=None
    start_t=0
    qualified=False
    for (x,y,t) in samples:
        current=(x,y)
        seg=(x-prior[0],y-prior[1])
        radial=(prior[0]-pivot[0],prior[1]-pivot[1])
        d=math.hypot(*seg)
        r=math.hypot(*radial)
        if d>=2 and r>=168*.25:
            hd=(radial[0]/r,radial[1]/r)
            if seg[0]*hd[0]+seg[1]*hd[1] <= -.8*d:
                if stroke is None or t-start_t>120:
                    stroke=prior
                    start_t=previous_t
                net=(x-stroke[0],y-stroke[1])
                n=math.hypot(*net)
                duration=max(1,t-start_t)
                if (n>=32 and duration<=120 and n*1000/duration>=800
                    and net[0]*hd[0]+net[1]*hd[1]<=-.8*n
                    and (x-pivot[0])*hd[0]+(y-pivot[1])*hd[1]>0):
                    pivot=stroke
                    qualified=True
                    stroke=None
            else:
                stroke=None
        elif d>=2:
            stroke=None
        prior=current
        previous_t=t
    return qualified,pivot,(prior[0]-pivot[0],prior[1]-pivot[1])

fast=recognize((0,0),[(100,0,250),(85,0,266),(70,0,282),(60,0,298)])
assert fast[0] and fast[1]==(100,0) and fast[2][0]<0,fast
slow=recognize((0,0),[(100,0,250),(88,0,326),(76,0,402),(64,0,478),(52,0,554)])
assert not slow[0] and slow[2][0]>0,slow
side=recognize((0,0),[(100,0,250),(99,14,266),(95,26,282),(94,40,298)])
assert not side[0],side
tiny=recognize((0,0),[(100,0,250),(97,0,266),(101,0,282),(98,0,298)])
assert not tiny[0],tiny
boost=recognize((0,0),[(220,0,250),(207,0,266),(194,0,282),(181,0,298)])
assert boost[0] and math.hypot(*boost[2])<168*1.10,boost
print("v154 static and 5 analog recognition cases PASS; Godot/Android NOT TESTED")
