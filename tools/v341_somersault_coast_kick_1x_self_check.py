#!/usr/bin/env python3
"""SERA v341: continuous rear velocity and one-speed authored lateral kicks."""
import json,math
from pathlib import Path
r=Path(__file__).resolve().parents[1]
m=(r/"scripts/main.gd").read_text()
rig=(r/"scripts/sera_rig.gd").read_text()
spec=json.loads((r/"tools/sera_active_specs.json").read_text())
assert 'config/name="SERA v341"' in (r/"project.godot").read_text()
assert spec["side_kick"]["motion_time_multiplier"]==1
assert "const SIDE_KICK_MOTION_TIME_MULTIPLIER: float = 1.0" in m
assert "const SIDE_KICK_DURATION_REFERENCE_DISTANCE: float = 3.0" in m
assert "const SIDE_KICK_BOOST_DISTANCE: float = 4.0" in m
assert "const BACK_SOMERSAULT_DISTANCE: float = 5.0" in m
assert "const BACK_SOMERSAULT_HEIGHT: float = 1.5" in m
assert "const BACK_SOMERSAULT_LANDING_SLIDE_DISTANCE: float = 0.30" in m
assert "const BACK_SOMERSAULT_LANDING_SECONDS: float = 0.20" in m
assert "terminal_rear_control + control_up, finish, p" in m
assert "1.0 - remaining * remaining * remaining" in m
assert "if landing_from_somersault and back_somersault_hit:" in m
assert "_move_player_swept(back_somersault_direction * coast_distance, true)" in m
assert "back_somersault_landing_slide_previous = coast_offset" in m
assert 'side_kick_playback_scale = maxf(0.001, float(animations[chosen]["length"])) / maxf(movement_duration, 0.01)' in rig
duration=.8*(1-.20833/.79167)
coast=.30
landing=.20
control=5.-coast*duration/landing
x=lambda t: 3*(1-t)*t*t*control+5*t*t*t
slide=lambda t: coast*(1-(1-t)**3)
assert x(0)==0 and x(1)==5
assert all(x((i+1)/120)>x(i/120) for i in range(120))
assert all(slide((i+1)/120)>slide(i/120) for i in range(120))
assert math.isclose(3*(5-control)/duration,3*coast/landing,abs_tol=1e-12)
assert math.isclose(slide(1),coast,abs_tol=1e-12)
assert math.isclose(3/10*1,.30,abs_tol=1e-12)
print("PASS v341 5m continuous air retreat + 0.30m easing grounded retreat; Kick_l/r 1x")
