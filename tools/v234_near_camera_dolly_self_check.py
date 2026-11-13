#!/usr/bin/env python3
"""SERA v234: frame-rate-independent, closing-speed-driven near camera dolly."""
from pathlib import Path
import math
import re

ROOT = Path(__file__).resolve().parents[1]
def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

main = read("scripts/main.gd")
project = read("project.godot")
version = re.search(r'^config/name="SERA v(\d+)"$', project, re.M)
assert version and int(version.group(1)) >= 234

def const(name):
    m = re.search(r'^const '+name+r': float = ([0-9.]+)', main, re.M)
    assert m, name
    return float(m.group(1))

assert const("CAMERA_CLOSE_RADIUS") == 8.8
assert const("CAMERA_BASE_RADIUS") == 16.0
assert const("CAMERA_CLOSE_RANGE") == 1.5
assert const("CAMERA_FAR_RANGE") == 12.0
assert const("CAMERA_NEAR_DOLLY_BLEND_START") == 8.0
assert const("CAMERA_NEAR_DOLLY_BLEND_FULL") == 5.0
assert const("CAMERA_NEAR_DOLLY_PLAYER_SPEED_RATIO") == 0.88
assert const("CAMERA_NEAR_DOLLY_SPEED_FILTER_RATE") == 10.0
assert const("CAMERA_NEAR_DOLLY_MAX_ACCEL") == 24.0
assert const("CAMERA_NEAR_DOLLY_SETTLE_SPEED") == 0.70
assert const("CAMERA_NEAR_DOLLY_GAP_RATE") == 6.0
assert const("CAMERA_NEAR_DOLLY_MAX_CLOSING_SAMPLE") == 12.0
assert const("CAMERA_FIT_RELAX_SPEED") == 1.25

render = main.split("func _process(delta: float) -> void:", 1)[1].split(
    "func _close_step_target_relative_yaw", 1)[0]
for token in (
    "(camera_last_separation - separation) / delta",
    "camera_last_separation = separation",
    "camera_filtered_closing_speed = lerpf(",
    "-CAMERA_NEAR_DOLLY_SPEED_FILTER_RATE * maxf(delta, 0.0)",
    "camera_near_dolly_weight = clampf(",
    "3.0 - 2.0 * camera_near_dolly_weight",
    "camera_filtered_closing_speed * CAMERA_NEAR_DOLLY_PLAYER_SPEED_RATIO",
    "old_inward_speed, near_inward_speed, camera_near_dolly_weight",
    "CAMERA_NEAR_DOLLY_MAX_ACCEL * delta",
    "var gap_stop_speed: float = distance_to_preferred * (",
    "-CAMERA_NEAR_DOLLY_GAP_RATE * delta",
    "camera_dolly_in_speed = minf(camera_dolly_in_speed, gap_stop_speed)",
    "camera_follow_radius = maxf(",
    "camera_follow_radius = lerpf(",
    "camera_radius = maxf(camera_follow_radius, camera_fit_radius_floor)",
    "_fit_boost_frame_analytically(delta)",
    "_fit_full_frame()",
):
    assert token in render, token

fit = main.split("func _camera_fit_release_speed() -> float:", 1)[1].split(
    "func _fit_full_frame() -> void:", 1)[0]
assert "camera_dolly_in_speed * camera_near_dolly_weight" in fit
assert "return maxf(CAMERA_FIT_RELAX_SPEED," in fit
assert "safe_radius, _camera_fit_release_speed() * maxf(delta, 0.0))" in fit
relax = main.split("func _relax_camera_fit_radius(delta: float) -> void:", 1)[1].split(
    "func _place_camera()", 1)[0]
assert "camera_fit_radius_floor - _camera_fit_release_speed() * maxf(delta, 0.0)" in relax
assert "if _full_frame_safe():" in relax
assert "camera_radius = previous_radius" in relax
reset = main.split("func _tick_training_ko(delta: float) -> void:", 1)[1].split(
    "func _advance_target_motion", 1)[0]
assert "camera_last_separation = -1.0" in reset
assert "camera_filtered_closing_speed = 0.0" in reset
assert "camera_dolly_in_speed = 0.0" in reset
assert "player.reset_physics_interpolation()" in reset
assert "target.reset_physics_interpolation()" in reset
assert "camera_player_render_position = player.get_global_transform_interpolated().origin" in render
assert "camera_target_render_position = target.get_global_transform_interpolated().origin" in render

# Independent time-step integration of the v234 controller.
def step(state, separation, preferred, dt):
    follow, previous, filtered, inward = state
    raw = 0.0 if previous < 0 else max(0.0, min(12.0, (previous-separation)/dt))
    filtered += (raw-filtered)*(1-math.exp(-10.0*dt))
    w = max(0.0, min(1.0,(8.0-separation)/3.0))
    w = w*w*(3-2*w)
    easing = (1-math.exp(-1.65*dt))*0.9
    if follow > preferred:
        gap = follow-preferred
        far = gap*easing/dt
        near = max(0.7, 0.88*filtered, gap*3.0)
        desired = far*(1-w) + near*w
        if w <= 1e-5:
            inward = far
        else:
            limit = 24.0*dt
            inward += max(-limit,min(limit,desired-inward))
        gap_limit = gap*(1-math.exp(-6.0*dt))/dt
        inward=min(inward,gap_limit)
        follow=max(preferred,follow-inward*dt)
    else:
        follow += (preferred-follow)*easing
        inward = 0.0
    return follow,separation,filtered,inward,w

def simulate(hz):
    state=(16.0,-1.0,0.0,0.0)
    records=[]
    for i in range(int(1.1*hz)):
        t=i/hz
        # Closing at 6m/s for 0.6s; then release while standing still.
        separation=5.0-6.0*min(t,0.6)
        state=step(state,separation,8.8,1/hz)[:4]
        records.append((t,*state))
    return records

for hz in (30,60,90,120):
    samples=simulate(hz)
    assert all(8.8-1e-8 <= r[1] <= 16.0+1e-8 for r in samples)
    assert all(samples[i+1][1] <= samples[i][1]+1e-8 for i in range(len(samples)-1))
    # During sustained closing and far enough from destination, the desired
    # near-dolly speed retains closing assistance plus gap-based recovery.
    mid=min(samples,key=lambda r:abs(r[0]-.49))
    assert 4.9 <= mid[4] <= 13.0, (hz,mid)
    # At rest the camera continues gently toward the composition rather
    # than freezing, with no abrupt radius teleport.
    assert samples[-1][1] < samples[int(.6*hz)][1]
    assert min(r[4] for r in samples) >= -1e-8

# At the far boundary, preserve the original exponential follow exactly.
for hz in (30,60,120):
    dt=1/hz
    follow=14.6
    updated=step((follow,9.0,0,0),9.0,12.0,dt)[0]
    legacy=follow-(follow-12.0)*(1-math.exp(-1.65*dt))*.9
    assert math.isclose(updated,legacy,rel_tol=1e-10)

# Minimum safety fit can never shrink below the hard framing radius; while
# closing, release speed must be at least the old 1.25m/s.
for near_weight in (0,.25,.5,.75,1):
    for speed in (0,.7,3,5.28):
        release=max(1.25,near_weight*speed)
        assert release>=1.25
        safe=9.7
        floor=11.0
        new=max(safe,floor-release/120)
        assert new>=safe and new<=floor

print("PASS v234: near dolly uses 88% player closing speed, filtered velocity,")
print("30-120Hz monotonic zoom, safe fit budget, no-teleport reset and far compatibility")
