#!/usr/bin/env python3
"""v278/v280: 2x kick timeline, full clips and second-windup STEP travel."""
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
    "var travel_progress: float = progress",
    "if side_kick_active:",
    "var second_windup: float = (SIDE_KICK_SECOND_WINDUP_R",
    "(progress - second_windup) * SIDE_KICK_MOTION_TIME_MULTIPLIER",
    "step_linear_offset * travel_progress",
    "_configure_side_kick_orbit()",
    "step_target_center = Vector2(target.position.x, target.position.z)",
    "step_radial_delta * (",
    "step_signed_angle * travel_progress",
    "func _configure_side_kick_orbit() -> void:",
    "var previous_progress: float = step_elapsed / step_duration_current",
    "SIDE_KICK_HIT_PROGRESS = [0.25, 0.58333]",
    "SIDE_KICK_SECOND_WINDUP_R: float = 0.33333",
    "SIDE_KICK_SECOND_WINDUP_L: float = 0.41667",
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
