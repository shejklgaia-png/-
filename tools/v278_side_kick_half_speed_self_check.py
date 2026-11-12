#!/usr/bin/env python3
"""v278 checks 2x lateral kick timeline, full authored clips and original travel."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "scripts/main.gd").read_text()
rig = (ROOT / "scripts/sera_rig.gd").read_text()
source = json.loads((ROOT / "assets/sera_source.json").read_text())
import re
version = re.search(r'config/name="SERA v([0-9]+)"',
    (ROOT / "project.godot").read_text())
assert version and int(version.group(1)) >= 278
for text in (
    "const SIDE_KICK_MOTION_TIME_MULTIPLIER: float = 2.0",
    "step_duration_current *= SIDE_KICK_MOTION_TIME_MULTIPLIER",
    "var travel_progress: float = (minf(1.0, progress * SIDE_KICK_MOTION_TIME_MULTIPLIER)",
    "if side_kick_active else progress)",
    "step_linear_offset * travel_progress",
    "step_radial_delta * travel_progress",
    "step_signed_angle * travel_progress",
    "var previous_progress: float = step_elapsed / step_duration_current",
    "SIDE_KICK_HIT_PROGRESS = [0.25, 0.58333]",
    "step_duration_current * previous_progress",
    'rig.call("start_side_kick", step_kick_side_request, step_duration_current)',
    "BACK_SOMERSAULT_FLIGHT_SECONDS: float = 0.80",
    "BACK_SOMERSAULT_LANDING_SECONDS: float = 0.20",
):
    assert text in main, text
assert 'side_kick_playback_scale = maxf(0.001, float(animations[chosen]["length"])) / maxf(movement_duration, 0.01)' in rig
clips = {a["name"]: a for a in source["animations"]}
assert all(float(clips[name]["length"]) == 1.0 for name in ("Kick_l", "Kick_r"))
assert abs(float(clips["Kick_b"]["length"])-0.79167) < 0.00002
print("V278_SIDE_KICK_HALF_SPEED_STATIC_PASS")
