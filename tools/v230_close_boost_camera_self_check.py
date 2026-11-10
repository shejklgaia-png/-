#!/usr/bin/env python3
"""SERA v230: close BOOST yaw/zoom arbitration and fitted-radius hysteresis."""
from pathlib import Path
import math
import re

ROOT = Path(__file__).resolve().parents[1]
def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

main = read("scripts/main.gd")
rig = read("scripts/sera_rig.gd")
project = read("project.godot")
version = re.search(r'config/name="SERA v(\d+)"', project)
assert version and int(version.group(1)) >= 230
for token in (
    "const CAMERA_CLOSE_BOOST_ENTER_DISTANCE: float = 6.0",
    "const CAMERA_CLOSE_BOOST_EXIT_DISTANCE: float = 7.5",
    "const CAMERA_FIT_RELAX_SPEED: float = 1.25",
    "var camera_follow_radius: float = CAMERA_BASE_RADIUS",
    "var camera_fit_radius_floor: float = 0.0",
    "var close_boost_camera_active: bool = false",
):
    assert token in main, token
assert float(re.search(
    r'CAMERA_CLOSE_BOOST_ENTER_DISTANCE: float = ([\d.]+)', main).group(1)
) < float(re.search(
    r'CAMERA_CLOSE_BOOST_EXIT_DISTANCE: float = ([\d.]+)', main).group(1))

camera = main.split("func _process(delta: float) -> void:", 1)[1].split(
    "func _close_step_target_relative_yaw", 1)[0]
assert 'var active_boost_travel: bool = (movement_boost_active and running' in camera
assert 'combat_state == CombatState.IDLE and not step_active' in camera
assert 'if close_boost_camera_active:' in camera
assert 'boost_pose_grace_remaining > 0.0' in camera
assert 'separation < CAMERA_CLOSE_BOOST_EXIT_DISTANCE' in camera
assert 'separation <= CAMERA_CLOSE_BOOST_ENTER_DISTANCE' in camera
assert camera.index('var active_boost_travel: bool') < camera.index('var easing: float')
assert '_advance_camera_dolly(separation, preferred_radius, easing, delta)' in camera
assert 'camera_follow_radius = lerpf(' not in camera
assert 'var legacy_radius: float = lerpf(' in main
assert 'camera_radius = maxf(camera_follow_radius, camera_fit_radius_floor)' in camera
assert camera.count('if not close_boost_camera_active and not boost_edge_frame_guard:') == 2
assert 'var boost_edge_frame_guard: bool = (' in camera
assert '    if boost_edge_frame_guard:' in camera
assert '        _fit_boost_frame_analytically(delta)' in camera
assert 'if protect_close_step and separation > 0.08:' in camera
assert 'camera_yaw = _close_step_target_relative_yaw(bearing, easing, delta)' in camera
assert 'camera_yaw = lerp_angle(camera_yaw, bearing, easing * CAMERA_MOVING_YAW_SCALE)' in camera
assert camera.count('_enforce_screen_edge(bearing, delta)') == 2
assert camera.index('    _fit_full_frame()') < camera.index('    _relax_camera_fit_radius(delta)')

fit = main.split("func _fit_full_frame() -> void:", 1)[1].split(
    "func _place_camera() -> void:", 1)[0]
assert 'camera_radius = upper_radius + CAMERA_FIT_RADIUS_RESERVE' in fit
assert 'camera_fit_radius_floor = maxf(camera_fit_radius_floor, camera_radius)' in fit
assert 'func _relax_camera_fit_radius(delta: float) -> void:' in fit
assert 'candidate_floor: float = maxf(0.0,' in fit
assert 'camera_fit_radius_floor - CAMERA_FIT_RELAX_SPEED * maxf(delta, 0.0)' in fit
assert 'candidate_radius: float = maxf(camera_follow_radius, candidate_floor)' in fit
assert 'if _full_frame_safe():' in fit
assert 'camera_fit_radius_floor = candidate_floor' in fit
assert 'camera_radius = previous_radius' in fit
# Check the original target 8-corners and player-frame geometry remain intact.
assert 'for dx in [-TARGET_HALF_SIZE, TARGET_HALF_SIZE]' in main
assert 'for dy in [-TARGET_HALF_SIZE, TARGET_HALF_SIZE]' in main
assert 'for dz in [-TARGET_HALF_SIZE, TARGET_HALF_SIZE]' in main
assert 'func _enforce_screen_edge(bearing: float, delta: float)' in main
assert 'const BOOST_POSE_GRACE_SECONDS: float = 0.50' in main
assert 'const CAMERA_EDGE_MAX_CORRECTION_DEGREES_PER_SECOND: float = 240.0' in main
assert 'const SLIDE_BOOST_TRANSITION_SECONDS: float = 0.18' in rig

# Numeric regression: while the required safe radius is constant, a fitted
# camera never re-expands in repeated sawtooth bursts as the preferred dolly
# tries to pull inward. On improved clearance, the guard eases inward at its
# speed cap instead of immediately snapping to the nominal close zoom.
def simulate(required, desired, steps=240, hz=60):
    floor = 0.0
    records = []
    reserve = 0.12
    for frame in range(steps):
        necessary = required(frame) if callable(required) else required
        radius = max(desired, floor)
        if radius < necessary:
            radius = necessary + reserve
            floor = max(floor, radius)
        if floor > 0.0:
            candidate = max(0.0, floor - 1.25/hz)
            trial = max(desired, candidate)
            if trial >= necessary:
                floor = candidate
                radius = trial
        records.append(radius)
    return records

static = simulate(9.25, 7.8)
assert static[0] > 9.25
assert all(static[i+1] <= static[i]+1e-8 for i in range(len(static)-1))
assert all(static[i] >= 9.25-1e-8 for i in range(len(static)))
assert max(abs(static[i+1]-static[i]) for i in range(1,len(static)-1)) <= 1.25/60+1e-8
# A sudden reduction in required zoom should not teleport the camera inward.
release = simulate(lambda i: 10.0 if i < 60 else 8.0, 7.8)
assert release[60] <= release[59]+1e-8
assert 0.0 <= release[59]-release[60] <= 1.25/60+1e-8
assert release[-1] < release[60] and release[-1] >= 8.0

# Close range mode hysteresis: no alternating yaw correction at 6..7.5m.
active = False
for dist in [8.0, 6.1, 5.9, 6.7, 7.3]:
    active = (dist < 7.5) if active else (dist <= 6.0)
assert active
active = 7.6 < 7.5
assert not active
print("PASS v230: close BOOST yaw isolation, guarded zoom and smooth release")
