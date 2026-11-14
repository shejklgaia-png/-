#!/usr/bin/env python3
"""Historical 4m STEP, full locked-part kick chase and current exit rule."""
import re
from pathlib import Path
r=Path(__file__).resolve().parents[1]
m=(r/"scripts/main.gd").read_text()
rig=(r/"scripts/sera_rig.gd").read_text()
manifest=(r/"tools/sera_ci_manifest.txt").read_text()
assert int(re.search(r'config/name="SERA v(\d+)"',(r/"project.godot").read_text()).group(1))>=340
for token in ("const STEP_FORWARD_DISTANCE: float = 4.0",
    "const STEP_SIDE_DISTANCE: float = 4.0","const BACK_STEP_DISTANCE: float = 4.0",
    "const BACK_SOMERSAULT_DISTANCE: float = 5.0",
    "const SIDE_KICK_BOOST_DISTANCE: float = 4.0",
    "const SIDE_KICK_DURATION_REFERENCE_DISTANCE: float = 3.0",
    "const STEP_SPEED: float = 15.0",
    "const SIDE_KICK_STEP_SPEED: float = 10.0"):
    assert token in m,token
start=m.split("func _start_omni_step(flick: Vector2) -> bool:",1)[1].split("func _start_back_step(",1)[0]
for token in ("step_arc_length = _step_fixed_distance_for_direction(direction)",
              "step_duration_current = (step_arc_length / step_speed_current",
              "side_kick_active = step_kick_side_request != 0",
              "step_arc_length = SIDE_KICK_BOOST_DISTANCE",
              "step_linear_fallback = true","step_linear_fallback = false",
              "SIDE_KICK_DURATION_REFERENCE_DISTANCE / step_speed_current",
              "side_kick_linear_direction = Vector2("):
    assert token in start,token
assert "_step_speed_for_player_position(" not in start
assert "_configure_side_kick_orbit" not in m
assert "side_kick_orbit_sign" not in m
advance=m.split("func _advance_side_step(delta: float) -> void:",1)[1].split("func _move_player_swept(",1)[0]
for token in ("var second_hit: float = float(SIDE_KICK_HIT_PROGRESS[1])",
              "_advance_homing_toward_target(chase_dt, BASH_REACH)",
              "_advance_homing_toward_target(second_chase_dt, SIDE_KICK_REACH)",
              "side_kick_linear_active = true","side_kick_linear_start_elapsed = step_elapsed",
              "side_kick_linear_direction * side_kick_linear_distance * line_progress",
              "if previous_progress < impact_progress and progress >= impact_progress:"):
    assert token in advance,token
assert "step_signed_angle * orbit_progress" not in advance
assert "func _back_somersault_arc_offset(progress: float) -> Vector3:" in m
assert 'side_kick_playback_scale = maxf(0.001, float(animations[chosen]["length"])) / maxf(movement_duration, 0.01)' in rig
for line in ("py tools/v300_fixed_step_locked_kick_self_check.py",
             "gd tools/v300_fixed_step_locked_kick_runtime_check.gd"):
    assert line in manifest
print("V300_FIXED_STEP_LOCKED_KICK_STATIC_PASS (4m next-frame line)")
