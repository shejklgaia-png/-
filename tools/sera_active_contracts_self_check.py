#!/usr/bin/env python3
"""Protect current SERA gameplay values and STEP/kick wiring."""
import re
from sera_active_contracts import ROOT, load_active_specs, main_float_constant, require_close

source = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
project = (ROOT / "project.godot").read_text(encoding="utf-8")
spec = load_active_specs()
version = re.search(r'^config/name="SERA v(\d+)"$', project, re.MULTILINE)
assert version and int(version.group(1)) >= spec["approved_at_version"]
step = spec["ordinary_step"]
kick = spec["side_kick"]
for name in ("BACK_STEP_DISTANCE", "STEP_FORWARD_DISTANCE", "STEP_SIDE_DISTANCE",
             "STEP_MIN_ARC_LENGTH", "STEP_MAX_ARC_LENGTH"):
    require_close(main_float_constant(source, name), step["distance_m"], name)
for name, expected in (
    ("STEP_SPEED", step["speed_mps"]),
    ("STEP_LAUNCH_WARP_DISTANCE", step["launch_warp_m"]),
    ("STEP_LAUNCH_FX_SECONDS", step["launch_fx_s"]),
    ("SIDE_KICK_BOOST_DISTANCE", kick["distance_m"]),
    ("SIDE_KICK_STEP_SPEED", kick["speed_mps"]),
):
    require_close(main_float_constant(source, name), expected, name)
assert 0 < step["launch_warp_m"] < step["distance_m"]
assert 0 < step["distance_m"] / step["speed_mps"] <= main_float_constant(source, "STEP_MAX_DURATION")
assert 0 < step["launch_fx_s"] <= 0.25
assert kick["distance_m"] > 0 and kick["speed_mps"] > 0
ordinary = source.split("func _start_omni_step(flick: Vector2) -> bool:", 1)[1].split(
    "func _start_back_step()", 1)[0]
for token in (
    "step_arc_length = _step_fixed_distance_for_direction(direction)",
    "step_speed_current = STEP_SPEED * float(part_stats.get",
    "step_arc_length = SIDE_KICK_BOOST_DISTANCE",
    'rig.call("capture_step_launch_afterimage", STEP_LAUNCH_FX_SECONDS)',
    'rig.call("spawn_step_launch_flare", world_step, STEP_LAUNCH_FX_SECONDS)',
    "_move_player_swept(world_step.normalized() * minf(",
):
    assert token in ordinary, "Current mechanic missing: " + token
assert "_step_speed_for_player_position(" not in ordinary
print("ACTIVE_SERA_CONTRACT_PASS")
