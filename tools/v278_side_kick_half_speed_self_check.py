#!/usr/bin/env python3
"""Historical 2x authored side-kick motion and v340 post-contact linear exit."""
from pathlib import Path
import json,re
r=Path(__file__).resolve().parents[1]
m=(r/"scripts/main.gd").read_text()
rig=(r/"scripts/sera_rig.gd").read_text()
assets=json.loads((r/"assets/sera_source.json").read_text())
ver=int(re.search(r'config/name="SERA v(\d+)"',(r/"project.godot").read_text()).group(1))
assert ver>=340
assert "const SIDE_KICK_MOTION_TIME_MULTIPLIER: float = 1.0" in m
assert "const SIDE_KICK_DURATION_REFERENCE_DISTANCE: float = 3.0" in m
assert "const SIDE_KICK_BOOST_DISTANCE: float = 4.0" in m
assert "SIDE_KICK_DURATION_REFERENCE_DISTANCE / step_speed_current" in m
assert "const SIDE_KICK_HIT_PROGRESS = [0.25, 0.58333]" in m
assert "SIDE_KICK_SECOND_WINDUP_R: float = 0.33333" in m
assert "SIDE_KICK_SECOND_WINDUP_L: float = 0.41667" in m
assert "side_kick_linear_start_elapsed = step_elapsed" in m
assert "side_kick_linear_direction * side_kick_linear_distance * line_progress" in m
assert "step_signed_angle * orbit_progress" not in m
assert "_configure_side_kick_orbit" not in m
assert 'rig.call("start_side_kick", step_kick_side_request, step_duration_current)' in m
assert 'side_kick_playback_scale = maxf(0.001, float(animations[chosen]["length"])) / maxf(movement_duration, 0.01)' in rig
clips={x["name"]:x for x in assets["animations"]}
for name in ("Kick_l","Kick_r"): assert float(clips[name]["length"])==1.0
assert abs(float(clips["Kick_b"]["length"])-0.79167)<0.00002
print("V278_SIDE_KICK_HALF_SPEED_STATIC_PASS (2x clip, 4m post-contact)")
