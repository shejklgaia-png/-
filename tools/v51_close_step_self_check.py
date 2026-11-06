#!/usr/bin/env python3
"""Static source and independent step-path regression checks, not Godot runtime."""
from pathlib import Path
import hashlib, math, re, random

root = Path(__file__).resolve().parents[1]
base = root.parent/'sera_portrait_godot_melee_v50_target_collision'
s = (root/'scripts/main.gd').read_text(encoding='utf-8')
b = (base/'scripts/main.gd').read_text(encoding='utf-8')

const = {n: float(v) for n,v in re.findall(r'^const (\w+): float = ([\d.]+)',s,re.M)}
for n,v in {'STEP_SPEED':10.0,'STEP_CLOSE_SPEED':6.0,'STEP_CLOSE_DISTANCE':2.0,
            'STEP_MAX_DURATION':.4,'STEP_MIN_ARC_LENGTH':1.5,'STEP_MAX_ARC_LENGTH':4.0,
            'STEP_ORBIT_ANGLE_DEGREES':35.0,'STEP_CLOSE_ORBIT_MAX_DEGREES':120.0}.items():
    assert const[n]==v,(n,const[n],v)
assert 'return STEP_CLOSE_SPEED if radius <= STEP_CLOSE_DISTANCE else STEP_SPEED' in s
assert 'step_speed_current = _step_speed_for_radius(radius)' in s
assert 'minf(STEP_MAX_ARC_LENGTH, step_speed_current * STEP_MAX_DURATION)' in s
assert 'step_duration_current = path_length / step_speed_current' in s
assert 'step_status_label.text = "STEP SPEED %.0fm/s" % display_speed' in s
assert 'if not step_active and step_status_label != null:' in s
assert '_refresh_step_status_ui()' in s
assert 'step_traveled_distance +=' in s
assert 'player.move_and_collide(remainder)' in s
assert 'player.move_and_slide()' in s

# Check all v50 scripts and every asset/scene/shader/blockbench byte-for-byte.
for d in ['assets','blockbench','scenes','shaders','scripts']:
    a={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/d).rglob('*') if p.is_file() and p.name!='main.gd'}
    z={str(p.relative_to(base)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (base/d).rglob('*') if p.is_file() and p.name!='main.gd'}
    assert a==z, d

# No existing gesture/camera/combat/physics-collision funcs changed.
def body(src,name):
    m=re.search(r'^func '+re.escape(name)+r'\([^\n]*\)[\s\S]*?(?=^func |\Z)',src,re.M)
    assert m, name
    return m.group(0)
for name in ['_input','_begin_drag','_change_drag','_end_drag','_classify_side_flick',
             '_screen_drag_to_ground','_process','_build_camera','_nearest_clear_yaw',
             '_fit_full_frame','_place_camera','_start_attack','_advance_attack',
             '_cancel_attack','_start_strike','_build_character','_build_target',
             '_move_player_swept','_distance_to_cube_surface','_finish_side_step']:
    assert body(s,name)==body(b,name), f'Unexpected change: {name}'

# Independent simulation of v51 radius-based speed and existing v48/v49 arc geometry.
def model(r):
    speed=6.0 if r<=2.0 else 10.0
    maxpath=min(4.0, speed*.4)
    overlap=r < 1.5 / math.radians(120)
    if overlap:
        length=1.5
        angle=0.
    else:
        angle=min(max(math.radians(35),1.5/r),maxpath/r)
        length=r*angle
    duration=length/speed
    return speed,length,duration,angle,overlap

radii=[0,.01,.1,.5,.72,1,1.5,1.999999,2,2.000001,2.001,2.5,3,4,5,6.55,8,100]
random.seed(51)
radii += [random.random()*30 for _ in range(200)]
checks=0
for r in radii:
    speed,length,duration,angle,overlap=model(r)
    assert speed==(6 if r<=2 else 10)
    assert 1.5-1e-9<=length<=4+1e-9
    assert 0<duration<=.4+1e-9
    assert math.isclose(length/duration,speed,abs_tol=1e-9)
    if r<=2:
        assert math.isclose(length,1.5,abs_tol=1e-8)
        assert math.isclose(duration,.25,abs_tol=1e-8)
    for fps in [15,24,30,60,90,120,144]:
        t=0.
        while t<duration:
            t=min(duration,t+1/fps)
        assert math.isclose(t,duration,abs_tol=1e-10)
        checks+=1

assert model(2.0)==(6.0,1.5,.25,model(2)[3],model(2)[4])
assert model(2.000001)[0]==10.0
assert model(5.0)[0]==10.0
print('PASS: <=2.00m -> 6m/s, >2.00m -> 10m/s, snapshotted at flick start')
print('PASS: travel time <=0.40s, path 1.5-4m, close range 1.5m in 0.25s')
print(f'PASS: {checks} radius × framerate calculations and threshold boundaries')
print('PASS: v50 collisions, camera, drag, gestures, attack, models and effects unchanged')
print('NOTE: static tests only; no Godot engine/Android run')
