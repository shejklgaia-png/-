#!/usr/bin/env python3
"""v155: stricter fast-reversal speed gate, unchanged opposite-angle criterion."""
import math
import re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=(root/"scripts/main.gd").read_text(encoding="utf-8")
project=(root/"project.godot").read_text(encoding="utf-8")
ui=(root/"scripts/touch_overlay.gd").read_text(encoding="utf-8")
rig=(root/"scripts/sera_rig.gd").read_text(encoding="utf-8")
def fconst(n):
    m=re.search(r"^const "+re.escape(n)+r": float = (-?[0-9.]+)",source,re.M)
    assert m,n
    return float(m.group(1))
if "SERA v156" not in project:
    print("SKIP: historical v155 controller test (requires SERA v156)")
    raise SystemExit(0)
assert 'config/name="SERA v156"' in project
assert fconst("FAST_REVERSE_MIN_SPEED_PIXELS_PER_SEC")==800.0
assert fconst("FAST_REVERSE_OPPOSITE_DOT")==-0.80
assert math.isclose(math.degrees(math.acos(-.80)),143.13010235415598,abs_tol=1e-9)
assert fconst("FAST_REVERSE_MIN_TRAVEL_PIXELS")==32.0
assert fconst("FAST_REVERSE_MIN_RADIAL_RATIO")==0.25
assert "FAST_REVERSE_MAX_STROKE_MSEC: int = 120" in source
assert "reverse_length * 1000.0 / float(reverse_elapsed_ms)" in source
assert ">= FAST_REVERSE_MIN_SPEED_PIXELS_PER_SEC" in source
assert "reverse_travel.dot(heading)" in source
assert "pointer_origin = reverse_stroke_origin" in source
assert "BOOST_CONFIRM_SECONDS: float = 0.10" in source
assert "BOOST_EXIT_RADIUS_RATIO: float = 1.10" in source
assert "func _draw_radial_controller(" in ui
assert "VISUAL_TURN_DEADBAND_DEGREES: float = 3.0" in rig

# Three 16ms reverse movements starting from (100, 0). Each first stroke
# starts after a contact at 250ms; elapsed is 48ms by the third event.
def qualifies_per_3_events(step_px,angle_degrees=180):
    displacement=3*step_px
    elapsed_ms=48
    cosine=math.cos(math.radians(angle_degrees))
    still_original_side=100-displacement*abs(cosine)>0
    return (displacement>=fconst("FAST_REVERSE_MIN_TRAVEL_PIXELS")
            and elapsed_ms<=120
            and displacement*1000/elapsed_ms>=fconst("FAST_REVERSE_MIN_SPEED_PIXELS_PER_SEC")
            and cosine<=fconst("FAST_REVERSE_OPPOSITE_DOT")
            and still_original_side)
assert not qualifies_per_3_events(10.0)  # 625px/s, below distance and speed
assert not qualifies_per_3_events(12.0)  # 750px/s, enough travel but not speed
assert qualifies_per_3_events(13.0)      # 812.5px/s and sufficient distance
assert qualifies_per_3_events(15.0)      # 937.5px/s
assert not qualifies_per_3_events(15.0,140)  # angle unchanged
assert qualifies_per_3_events(15.0,150)
print("v155 speed-only threshold and angle-preservation regression: PASS")
print("Godot / Android real-device execution: NOT TESTED")
