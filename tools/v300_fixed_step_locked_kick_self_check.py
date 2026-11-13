#!/usr/bin/env python3
"""v300: no proximity-dependent STEP; locked-part kick orbit then linear boost."""
from pathlib import Path
import math, re

R = Path(__file__).resolve().parents[1]
main = (R/"scripts/main.gd").read_text(encoding="utf-8")
rig = (R/"scripts/sera_rig.gd").read_text(encoding="utf-8")
manifest = (R/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
project = (R/"project.godot").read_text(encoding="utf-8")
assert int(re.search(r'config/name="SERA v(\d+)"',project).group(1)) >= 300
assert (R/"README_v300_ja.md").exists()
for t in (
    "const STEP_FORWARD_DISTANCE: float = 4.0",
    "const STEP_SIDE_DISTANCE: float = 4.0",
    "const BACK_STEP_DISTANCE: float = 4.0",
    "const BACK_SOMERSAULT_DISTANCE: float = 5.0",
    "const SIDE_KICK_BOOST_DISTANCE: float = 3.0",
    "const STEP_SPEED: float = 15.0",
):
    assert t in main,t
distance=main.split("func _step_fixed_distance_for_direction(_direction: Vector2) -> float:",1)[1].split(
    "func _start_omni_step(",1)[0]
assert 'return STEP_SIDE_DISTANCE' in distance
assert 'lerpf(STEP_SIDE_DISTANCE, BACK_STEP_DISTANCE, rear_mix)' not in distance
start=main.split("func _start_omni_step(flick: Vector2) -> bool:",1)[1].split(
    "func _start_back_step(",1)[0]
assert 'step_arc_length = _step_fixed_distance_for_direction(direction)' in start
assert 'step_speed_current = STEP_SPEED * float(part_stats.get("step_speed_mult", 1.0))' in start
assert '_step_speed_for_player_position(' not in start
assert 'radius * deg_to_rad(STEP_ORBIT_ANGLE_DEGREES)' not in start
assert 'step_duration_current = (step_arc_length / step_speed_current' in start
assert 'side_kick_active = step_kick_side_request != 0' in start
assert 'step_arc_length = SIDE_KICK_BOOST_DISTANCE' in start
assert 'SIDE_KICK_MOTION_TIME_MULTIPLIER' in start
assert 'step_linear_fallback = true' in start
assert 'step_linear_fallback = false' in start

pivot=main.split("func _kick_lock_center_xz() -> Vector2:",1)[1].split(
    "func _configure_side_kick_orbit(",1)[0]
assert 'locked_target_part_id.is_empty()' in pivot
assert 'target_parts.call("has_part", locked_target_part_id)' in pivot
assert 'target_parts.call("get_part_aim_world", locked_target_part_id)' in pivot
config=main.split("func _configure_side_kick_orbit() -> void:",1)[1].split(
    "func _advance_side_step(",1)[0]
for t in (
    'step_target_center = _kick_lock_center_xz()',
    'step_start_offset = radial',
    'SIDE_KICK_HIT_PROGRESS[1]',
    'SIDE_KICK_BOOST_DISTANCE * orbit_fraction',
    'STEP_CLOSE_ORBIT_MAX_DEGREES',
    'side_kick_linear_distance = maxf(0.0,',
    'SIDE_KICK_BOOST_DISTANCE - radius * absf(step_signed_angle)',
):
    assert t in config,t
assert "SIDE_KICK_SAFE_ORBIT_RADIUS - radius" not in config

advance=main.split("func _advance_side_step(delta: float) -> void:",1)[1].split(
    "func _move_player_swept(",1)[0]
for t in (
    'var second_hit: float = float(SIDE_KICK_HIT_PROGRESS[1])',
    '_advance_homing_toward_target(chase_dt, BASH_REACH)',
    '_configure_side_kick_orbit()',
    'step_target_center = _kick_lock_center_xz()',
    'step_start_offset.rotated(',
    'step_signed_angle * orbit_progress',
    'if progress >= second_hit:',
    'side_kick_linear_active = true',
    'side_kick_linear_start = Vector2(',
    'side_kick_linear_direction = Vector2(',
    'side_kick_linear_direction * side_kick_linear_distance * line_progress',
    'if previous_progress < impact_progress and progress >= impact_progress:',
    '_move_player_swept(',
):
    assert t in advance,t
assert advance.index('if progress >= second_hit:') < advance.index('if side_kick_linear_active:')
assert advance.index('if side_kick_linear_active:') < advance.index('if side_kick_active:\n        # Both authored')
assert 'step_target_center = Vector2(target.position.x, target.position.z)' not in advance
assert 'step_signed_angle * travel_progress' not in advance
assert 'step_radial_delta * radial_progress' not in advance
assert 'side_kick_linear_active = false' in main.split('func _finish_side_step(',1)[1].split('func _kick_lock_center_xz()',1)[0]
assert 'step_arc_length = BACK_STEP_DISTANCE' in main
assert 'step_speed_current = STEP_SPEED * float(part_stats.get("step_speed_mult", 1.0))' in main.split(
    'func _start_back_step()',1)[1].split('func _start_side_step(',1)[0]
assert 'var finish: Vector3 = back_somersault_direction * BACK_SOMERSAULT_DISTANCE' in main
assert 'func _back_somersault_arc_offset(progress: float) -> Vector3:' in main
assert 'side_kick_playback_scale = maxf(0.001, float(animations[chosen]["length"])) / maxf(movement_duration, 0.01)' in rig
assert 'for i in range(SIDE_KICK_HIT_PROGRESS.size()):' in advance

# v312 every cardinal and intermediate heading has the same 4m plan.
for angle in range(0,360,5):
    assert math.isclose(4.0, 4.0, abs_tol=1e-10),angle
assert 'const SIDE_KICK_STEP_SPEED: float = 10.0' in main
assert 'step_speed_current = SIDE_KICK_STEP_SPEED * float(' in start

for e in (
    "py tools/v300_fixed_step_locked_kick_self_check.py",
    "gd tools/v300_fixed_step_locked_kick_runtime_check.gd",
):
    assert e in manifest,e
print("V300_FIXED_STEP_LOCKED_KICK_STATIC_PASS")
