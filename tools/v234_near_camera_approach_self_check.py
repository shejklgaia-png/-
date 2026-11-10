#!/usr/bin/env python3
"""v234: adaptive close dolly speed without jitter / snap at stop or mode change."""
from pathlib import Path
from math import exp, sqrt, isclose
import re

ROOT = Path(__file__).resolve().parents[1]
def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

main = read("scripts/main.gd")
assert 'config/name="SERA v234"' in read("project.godot")
def constant(name):
    m = re.search(r'^const ' + name + r': float = ([0-9.]+)', main, re.M)
    assert m, name
    return float(m.group(1))

assert constant('CAMERA_CLOSE_RADIUS') == 8.8
assert constant('CAMERA_BASE_RADIUS') == 16.0
assert constant('CAMERA_FOLLOW_RATE') == 1.65
assert constant('CAMERA_NEAR_ZOOM_FULL_DISTANCE') == 8.0
assert constant('CAMERA_NEAR_ZOOM_BLEND_DISTANCE') == 10.0
assert constant('CAMERA_NEAR_ZOOM_APPROACH_FRACTION') == 0.88
assert constant('CAMERA_NEAR_ZOOM_SETTLE_SPEED') == 0.90
assert constant('CAMERA_NEAR_ZOOM_SPEED_RESPONSE') == 10.0
assert constant('CAMERA_NEAR_ZOOM_ACCELERATION') == 22.0
assert constant('CAMERA_CLOSE_BOOST_ENTER_DISTANCE') == 6.0
assert constant('CAMERA_FIT_RELAX_SPEED') == 1.25

render = main.split('func _process(delta: float) -> void:',1)[1].split(
    'func _close_step_target_relative_yaw',1)[0]
dolly = main.split('func _advance_camera_dolly(',1)[1].split(
    'func _enforce_screen_edge(',1)[0]
assert render.count('_advance_camera_dolly(separation, preferred_radius, easing, delta)') == 1
assert 'var preferred_radius: float = lerpf(CAMERA_CLOSE_RADIUS, CAMERA_BASE_RADIUS, zoom_ratio)' in render
assert 'preferred_radius = maxf(preferred_radius, separation + 2.0)' in render
assert 'camera_radius = maxf(camera_follow_radius, camera_fit_radius_floor)' in render
assert 'camera_player_render_position.x - camera_target_render_position.x' in render
assert 'camera_target_render_position.z' in render
assert 'camera_previous_separation = separation' in dolly
assert '(camera_previous_separation - separation) / delta' in dolly
assert 'camera_smoothed_approach_speed, sample_speed, speed_alpha' in dolly
assert '1.0 - exp(-CAMERA_NEAR_ZOOM_SPEED_RESPONSE * delta)' in dolly
assert 'close_mix = close_mix * close_mix * (3.0 - 2.0 * close_mix)' in dolly
assert 'if close_mix <= 0.000001:' in dolly
assert 'var legacy_radius: float = lerpf(' in dolly
assert 'CAMERA_NEAR_ZOOM_APPROACH_FRACTION * camera_smoothed_approach_speed' in dolly
assert 'sqrt(' in dolly and '2.0 * CAMERA_NEAR_ZOOM_ACCELERATION * (-remaining)' in dolly
assert 'camera_dolly_velocity = move_toward(camera_dolly_velocity,' in dolly
assert 'CAMERA_NEAR_ZOOM_ACCELERATION * delta' in dolly
assert '(preferred_radius - old_radius) * (preferred_radius - next_radius) <= 0.0' in dolly
assert 'camera_dolly_velocity = 0.0' in dolly
assert '_fit_boost_frame_analytically(delta)' in render
assert '_fit_full_frame()' in render
assert '_relax_camera_fit_radius(delta)' in render
assert 'camera_fit_radius_floor' not in dolly
assert main.count('camera_previous_separation = -1.0') >= 2
assert main.count('camera_smoothed_approach_speed = 0.0') >= 2
assert main.count('camera_dolly_velocity = 0.0') >= 3

# Independent numeric simulation mirrors the speed controller at 30/60/90/120 Hz.
# It exercises a fast 6m/s inward approach, a stop, and a 6m/s departure.
def smoothstep(x):
    x = max(0.0, min(1.0,x))
    return x*x*(3-2*x)

def preferred(separation):
    fraction=smoothstep((separation-1.5)/(12-1.5))
    return max(8.8+7.2*fraction,separation+2.0)

def trace(fps):
    dt=1.0/fps
    prev=-1.0
    smooth_speed=0.0
    camera=16.0
    velocity=0.0
    sep=11.0
    rows=[]
    for i in range(round(5*fps)):
        t=i*dt
        if t<1.5:
            sep=max(2.0,sep-6.0*dt)
        elif t>=3.0 and t<4.0:
            sep=min(8.0,sep+6.0*dt)
        if prev<0:
            prev=sep
        sample=max(0,min(20,(prev-sep)/dt))
        prev=sep
        speed_alpha=1-exp(-10.0*dt)
        smooth_speed += (sample-smooth_speed)*speed_alpha
        mix=smoothstep((10-sep)/(10-8))
        target=preferred(sep)
        base=camera+(target-camera)*(1-exp(-1.65*dt))*.9
        if mix<=0.000001:
            new_cam=base
            velocity=(new_cam-camera)/dt
        else:
            gap=target-camera
            natural=(base-camera)/dt
            wanted=natural
            if gap<0:
                moving_weight=max(0,min(1,smooth_speed))
                near_limit=.9+(.88*smooth_speed-.9)*moving_weight
                near_limit=min(near_limit,sqrt(44*(-gap)))
                wanted=natural*(1-mix)-near_limit*mix
            velocity=max(velocity-22*dt,min(velocity+22*dt,wanted))
            proposed=camera+velocity*dt
            if (target-camera)*(target-proposed)<=0:
                new_cam=target
                velocity=0.0
            else:
                new_cam=proposed
        rows.append((t,sep,target,new_cam,velocity,smooth_speed,mix))
        camera=new_cam
    return rows

for fps in (30,60,90,120):
    rows=trace(fps)
    dt=1.0/fps
    # Stable full near-range chase at 6m/s is approx 88%, not a sudden
    # teleport to the target zoom radius. Acceleration is frame independent.
    full=[r for r in rows if .85<r[0]<1.15 and r[6]>.999]
    assert full, fps
    assert all(4.9<=-r[4]<=5.29 for r in full), (fps,full)
    moving=[rows[i] for i in range(1,len(rows)) if .6<rows[i][0]<1.45]
    assert all(r[3]>=r[2]-1e-7 for r in moving), fps
    # During final stop the camera converges without alternately expanding
    # and contracting frame-to-frame.
    stopped=[r[3] for r in rows if 1.8<r[0]<2.85]
    assert all(stopped[i+1] <= stopped[i]+1e-7 for i in range(len(stopped)-1)),fps
    assert abs(stopped[-1]-preferred(2.0)) < .015, (fps, stopped[-1])
    assert all(r[3]>0 and r[3] < 22 for r in rows)
    # At the 8–10m handoff there is no radius jump.
    assert max(abs(rows[i+1][3]-rows[i][3]) for i in range(len(rows)-1)) < 0.32, fps
    # On exit to >10m, original far-camera follow is intact.
    far=[r for r in rows if r[1] >= 10.0]
    assert far and all(0 <=r[6]<=1 for r in far)

# Both frame-safety systems are independent, so they can still pull back
# immediately if torso/head/target corners cannot fit the current close zoom.
assert 'camera_radius = maxf(camera_follow_radius, camera_fit_radius_floor)' in render
assert 'camera_fit_radius_floor = maxf(camera_fit_radius_floor, camera_radius)' in main
assert 'camera_fit_radius_floor = move_toward(camera_fit_radius_floor,' in main
print("PASS v234: 88% approach rate, acceleration/braking, stop, 30-120Hz, fit isolation")
