#!/usr/bin/env python3
"""v343: authored Kick_l and Kick_r nominally last 0.65 seconds."""
import json,math
from sera_active_contracts import require_min_version
from pathlib import Path
r=Path(__file__).resolve().parents[1]
m=(r/"scripts/main.gd").read_text()
rig=(r/"scripts/sera_rig.gd").read_text()
spec=json.loads((r/"tools/sera_active_specs.json").read_text())
assert require_min_version((r/"project.godot").read_text(), 343)
assert "const SIDE_KICK_MOTION_TIME_MULTIPLIER: float = 13.0 / 6.0" in m
assert "const SIDE_KICK_DURATION_REFERENCE_DISTANCE: float = 3.0" in m
assert "const SIDE_KICK_STEP_SPEED: float = 10.0" in m
assert "const SIDE_KICK_BOOST_DISTANCE: float = 4.0" in m
assert "const SIDE_KICK_HIT_PROGRESS = [0.25, 0.58333]" in m
assert "SIDE_KICK_DURATION_REFERENCE_DISTANCE / step_speed_current" in m
assert 'rig.call("start_side_kick", step_kick_side_request, step_duration_current)' in m
assert 'side_kick_playback_scale = maxf(0.001, float(animations[chosen]["length"])) / maxf(movement_duration, 0.01)' in rig
assert math.isclose(3/10*(13/6),.65,abs_tol=1e-12)
assert math.isclose(spec["side_kick"]["nominal_duration_s"],.65,abs_tol=1e-12)
assert math.isclose(spec["side_kick"]["motion_time_multiplier"],13/6,abs_tol=1e-12)
assert spec["side_kick"]["distance_m"]==4
assert spec["side_kick"]["post_hit_only"] is True
assert math.isclose(.65*.25,.1625,abs_tol=1e-12)
assert math.isclose(.65*.58333,.3791645,abs_tol=1e-8)
assert "const BACK_SOMERSAULT_FLIGHT_SECONDS: float = 0.80" in m
assert "const BACK_SOMERSAULT_LANDING_SECONDS: float = 0.20" in m
assert "const BACK_SOMERSAULT_LANDING_SLIDE_DISTANCE: float = 0.30" in m
print("PASS v343 0.65s lateral kicks, authored hit keys, 4m dash, Kick_b unchanged")
