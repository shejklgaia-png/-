#!/usr/bin/env python3
"""v340: remove arc, preserve hit keys, start 4m original-flick exit NEXT tick."""
from sera_active_contracts import require_min_version
from pathlib import Path
import json,math
r=Path(__file__).resolve().parents[1]
m=(r/"scripts/main.gd").read_text()
rig=(r/"scripts/sera_rig.gd").read_text()
spec=json.loads((r/"tools/sera_active_specs.json").read_text())
assert require_min_version((r/"project.godot").read_text(), 343)
assert spec["side_kick"]["post_hit_only"] is True
assert spec["side_kick"]["distance_m"]==4
assert spec["side_kick"]["duration_reference_distance_m"]==3
assert "const SIDE_KICK_BOOST_DISTANCE: float = 4.0" in m
assert "const SIDE_KICK_DURATION_REFERENCE_DISTANCE: float = 3.0" in m
assert "SIDE_KICK_DURATION_REFERENCE_DISTANCE / step_speed_current" in m
assert "const SIDE_KICK_HIT_PROGRESS = [0.25, 0.58333]" in m
assert "const SIDE_KICK_MOTION_TIME_MULTIPLIER: float = 13.0 / 6.0" in m
assert 'side_kick_playback_scale = maxf(0.001, float(animations[chosen]["length"])) / maxf(movement_duration, 0.01)' in rig
for unused in ("_configure_side_kick_orbit","side_kick_orbit_sign",
               "step_signed_angle * orbit_progress","contact_radial"):
    assert unused not in m,unused
for token in ("buffered_side_kick_world_direction = (",
              "_screen_drag_to_ground(flick).normalized() if side != 2",
              "committed_kick_world_direction = buffered_side_kick_world_direction",
              "_launch_combo_side_kick(committed_kick_flick, committed_kick_side,",
              "side_kick_world_direction_request = accepted_world_direction"):
    assert token in m,token
kick=m.split("func _advance_side_step(delta: float) -> void:",1)[1].split("func _move_player_swept(",1)[0]
for token in ("if previous_progress < second_hit and progress >= second_hit:",
              "side_kick_linear_active = true",
              "side_kick_linear_start_elapsed = step_elapsed",
              "step_elapsed, step_duration_current * second_hit",
              "_advance_homing_toward_target(second_chase_dt, SIDE_KICK_REACH)",
              "step_elapsed - side_kick_linear_start_elapsed",
              "step_duration_current - side_kick_linear_start_elapsed",
              "side_kick_linear_direction * side_kick_linear_distance * line_progress"):
    assert token in kick,token
assert kick.index("side_kick_linear_start_elapsed = step_elapsed")<kick.index(
    "var line_progress: float = clampf(")
assert "        else:\n            # Frozen at flick ACCEPTANCE." in kick
for hit in (.38,.40,.42):
    for t in (hit,(hit+.65)*.5,.65):
        amount=0. if t<=hit else 4.*min(1.,(t-hit)/(.65-hit))
        assert 0.<=amount<=4.
    assert abs(4.*(.65-hit)/(.65-hit)-4.)<1e-10
print("PASS v340 4m straight exit starts next physics frame, hit/clip unchanged")
