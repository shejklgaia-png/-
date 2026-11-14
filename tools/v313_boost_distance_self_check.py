#!/usr/bin/env python3
"""v314 correction to v313: restore continuous BOOST, STEP is now 4m."""
from sera_active_contracts import load_active_specs, main_float_constant
from pathlib import Path
import re
p=Path(__file__).resolve().parents[1]
s=(p/"scripts/main.gd").read_text(encoding="utf-8")
v=(p/"project.godot").read_text(encoding="utf-8")
assert int(re.search(r'config/name="SERA v(\d+)"',v).group(1))>=314
assert "BOOST_TRAVEL_DISTANCE" not in s
assert "boost_distance_traveled" not in s
assert "boost_distance_capped" not in s
assert 'const BOOST_SPEED_BLEND_SECONDS: float = 0.20' in s
assert 'const BOOST_POSE_GRACE_SECONDS: float = 0.50' in s
assert 'const STEP_SIDE_DISTANCE: float = 4.0' in s
assert 'const STEP_SPEED: float = 15.0' in s
assert main_float_constant(s, "SIDE_KICK_BOOST_DISTANCE") == load_active_specs()["side_kick"]["distance_m"]
assert (p/"docs/history/release_notes/README_v313_ja.md").is_file()
print("V313_BOOST_CAP_REVOKED_V314_CONTINUOUS_BOOST_STATIC_PASS")
