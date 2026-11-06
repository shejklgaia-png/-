#!/usr/bin/env python3
"""Static and numerical audits for the tap/boost/approach/slash prototype.
Not a replacement for running Godot on a device.
"""
import json
import math
import pathlib
import random

ROOT = pathlib.Path(__file__).resolve().parents[1]
source = json.loads((ROOT / 'assets/sera_source.json').read_text(encoding='utf-8'))
clips = {a['name']: a for a in source['animations']}
assert len(source['groups']) == 22
assert len(source['elements']) == 25
assert len(clips) == 7
assert {'Wait_motion','Wait_Pose','run_front_original','meleeboost','melee1','Step_L','Step_R'} == set(clips)

# Last authored boost key is 0.15s despite its 0.5s nominal duration.
def last_key(clip):
    return max(float(k['time']) for a in clip['animators'].values() for k in a.get('keyframes',[]) if k['channel'] in {'rotation','position'})

assert math.isclose(last_key(clips['meleeboost']), 0.15)
assert math.isclose(clips['meleeboost']['length'], 0.5)
assert math.isclose(clips['melee1']['length'], 0.5)
assert clips['meleeboost']['loop'] == clips['melee1']['loop'] == 'once'

main = (ROOT / 'scripts/main.gd').read_text(encoding='utf-8')
rig = (ROOT / 'scripts/sera_rig.gd').read_text(encoding='utf-8')
ui = (ROOT / 'scripts/touch_overlay.gd').read_text(encoding='utf-8')
assert all(f'CombatState.{s}' in main for s in ['IDLE','BOOST','DASH','STRIKE'])
assert 'rig.call("boost_last_key_reached")' in main
assert 'rig.call("hold_boost_last_pose")' in main
assert 'rig.call("clip_finished", "melee1")' in main
assert 'freeze_attack_pose = true' in rig
assert 'clip_time = float(animations[BOOST_CLIP]["last_key_time"])' in rig
assert 'if not freeze_attack_pose and not combat_paused:' in rig
assert 'pointing/emulate_mouse_from_touch=false' in (ROOT/'project.godot').read_text()
assert 'DRAG TO MOVE' in ui and 'TAP TO ATTACK' in ui
assert 'const MELEE_SURFACE_REACH: float = 0.75' in main
assert 'const MELEE_DASH_SPEED: float = 11.5' in main

# Ensure v9 camera parameters remain unchanged.
checks = {
    'MOVE_SPEED': '3.25', 'CAMERA_CLOSE_RADIUS': '6.5',
    'CAMERA_BASE_RADIUS': '16.0', 'CAMERA_CLOSE_RANGE': '1.5',
    'CAMERA_FAR_RANGE': '12.0', 'SCREEN_MARGIN_X': '0.02',
    'CAMERA_SAFE_CORE_HALF_WIDTH': '0.38', 'TARGET_HALF_SIZE': '1.0'
}
for name, value in checks.items():
    assert f'const {name}: float = {value}' in main, name

# Numerically reproduce the exact stop-at-first-surface-contact algorithm
# at multiple approach angles, distances and physics time steps.
boxhalf = 1.0
reach = 0.75
speed = 11.5
rng = random.Random(20261105)

def box_distance(x, z):
    return math.hypot(max(abs(x)-boxhalf,0.0),max(abs(z)-boxhalf,0.0))

def advance(x,z,dt):
    d=math.hypot(x,z)
    if box_distance(x,z)<=reach: return x,z,True
    travel = min(speed*dt,d)
    x2=x*(1-travel/d)
    z2=z*(1-travel/d)
    if box_distance(x2,z2)<=reach:
        lo,hi=0.,1.
        for _ in range(16):
            mid=(lo+hi)*0.5
            if box_distance(x+(x2-x)*mid,z+(z2-z)*mid)<=reach: hi=mid
            else: lo=mid
        x=x+(x2-x)*hi
        z=z+(z2-z)*hi
        return x,z,True
    return x2,z2,False

n=0
for dt in (1/120, 1/60, 1/20, 1/5, 0.9):
    for _ in range(350):
        direction = rng.uniform(-math.pi,math.pi)
        radius = rng.uniform(0.,70.)
        x,z = radius*math.sin(direction),radius*math.cos(direction)
        last=box_distance(x,z)
        for frame in range(1800):
            x,z,contact=advance(x,z,dt)
            after=box_distance(x,z)
            assert after <= last + 1e-8
            if contact:
                assert after <= reach + 1e-9
                # Starts beyond reach -> stops almost exactly at reach.
                if last > reach:
                    assert after >= reach - 0.0002, (last,after)
                break
            last=after
        else:
            raise AssertionError('DASH did not reach target')
        n += 1
print('Static clip/controller check: OK')
print('v9 camera and movement constants: OK')
print('Dash/contact tests:',n,'randomized scenarios: OK')
print('Runtime behavior still requires a Godot editor/Android test.')
