#!/usr/bin/env python3
"""v52 static camera/behavior validation; not a Godot runtime test."""
from pathlib import Path
import hashlib, math, re
root=Path(__file__).resolve().parents[1]
base=root.parent/'sera_portrait_godot_melee_v51_close_range_step_6ms'
main=(root/'scripts/main.gd').read_text(encoding='utf-8')
old=(base/'scripts/main.gd').read_text(encoding='utf-8')
consts={k:float(v) for k,v in re.findall(r'^const (\w+): float = ([\d.]+)',main,re.M)}
assert consts['CAMERA_CLOSE_RADIUS']==7.8
assert consts['CAMERA_BASE_RADIUS']==16.0
assert consts['CAMERA_ELEVATION_RATIO']==.11
assert consts['CAMERA_FOCUS_DROP']==.9
assert consts['SCREEN_MARGIN_BOTTOM']==.75
assert consts['TARGET_FRAME_BOTTOM']==.75
assert consts['SCREEN_MARGIN_TOP']==.06
assert consts['TARGET_FRAME_MARGIN_Y']==.045
assert consts['STEP_SPEED']==10.0 and consts['STEP_CLOSE_SPEED']==6.0
assert consts['STEP_CLOSE_DISTANCE']==2.0 and consts['STEP_MAX_DURATION']==.4
assert 'target.global_position - Vector3(0.0, CAMERA_FOCUS_DROP, 0.0)' in main
assert 'projected.y > size.y * TARGET_FRAME_BOTTOM' in main
assert 'lower_screen.y <= size.y * SCREEN_MARGIN_BOTTOM' in main
assert 'camera_radius = lerpf(camera_radius, preferred_radius, easing * 0.9)' in main
assert '_fit_full_frame()' in main

def func(s,name):
    hit=re.search(r'^func '+re.escape(name)+r'\([^\n]*\)[\s\S]*?(?=^func |\Z)',s,re.M)
    assert hit,name
    return hit.group(0)
# Everything except the world-camera placement and a camera zoom comment is identical to v51.
expected_changes={'_place_camera','_process','_target_fully_in_frame'}
names=set(re.findall(r'^func (\w+)\(',old,re.M))
assert names == set(re.findall(r'^func (\w+)\(',main,re.M))
for name in names-expected_changes:
    assert func(main,name)==func(old,name), 'changed unrelated function '+name
# Only camera-zoom comments change inside _process; execution is byte-for-byte identical.
def strip_comments(src):
    return '\n'.join(line for line in src.splitlines() if not line.lstrip().startswith('#'))
assert strip_comments(func(main,'_process')) == strip_comments(func(old,'_process'))
# The target's projected bottom margin is the only change in its frame check.
assert func(main,'_target_fully_in_frame')==func(old,'_target_fully_in_frame').replace(
    'projected.y > size.y * (1.0 - TARGET_FRAME_MARGIN_Y)',
    'projected.y > size.y * TARGET_FRAME_BOTTOM'
)
for d in ['assets','blockbench','scenes','shaders','scripts']:
    a={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).digest() for p in (root/d).rglob('*') if p.is_file() and p.name!='main.gd'}
    b={str(p.relative_to(base)):hashlib.sha256(p.read_bytes()).digest() for p in (base/d).rglob('*') if p.is_file() and p.name!='main.gd'}
    assert a==b, 'unexpected asset/script modification: '+d

# Independent perspective projection model for an exemplary XZ camera bearing.
# This is a mathematical sanity check, not the Godot renderer.
tan_v=math.tan(math.radians(61/2))
tan_h=tan_v*720/1280

def project(pos,radius,yaw):
    s,c=math.sin(yaw),math.cos(yaw)
    focus_y=1.53-consts['CAMERA_FOCUS_DROP']
    cam=(radius*s,focus_y+consts['CAMERA_ELEVATION_RATIO']*radius,radius*c)
    v=(pos[0]-cam[0], pos[1]-cam[1], pos[2]-cam[2])
    elev=consts['CAMERA_ELEVATION_RATIO']; norm=math.sqrt(1+elev*elev)
    right=(c,0,-s)
    up=(-elev*s/norm,1/norm,-elev*c/norm)
    forward=(-s/norm,-elev/norm,-c/norm)
    zz=sum(v[i]*forward[i] for i in range(3))
    if zz<=0: return None
    xx=sum(v[i]*right[i] for i in range(3))
    yy=sum(v[i]*up[i] for i in range(3))
    return (.5+xx/(2*zz*tan_h),.5-yy/(2*zz*tan_v))

# Demonstrate that the zoomed-out camera can fit target and both ends of
# the player above 75% across near, middle, and far representative locations.
checks=0
for d in [1.5,2,3,5,8,12]:
    # yaw offset mimics different drag/orbit camera positions
    for offset in [-.65,-.3,0,.3,.65]:
        yaw=offset
        radius=max(7.8, d+2)
        corners=[(x,1.53+y,z) for x in [-1,1] for y in [-1,1] for z in [-1,1]]
        # Surface of player projected at x=d along camera line.
        points=corners+[(0,.08,d),(0,1.85,d)]
        # At a separation of 12m the camera often needs to zoom out further.
        for _ in range(42):
            projections=[project(q,radius,yaw) for q in points]
            good=(all(q is not None for q in projections) and
                  all(.025<=q[0]<=.975 for q in projections[:8]) and
                  all(.045<=q[1]<=.75 for q in projections[:8]) and
                  all(.02<=q[0]<=.98 and .06<=q[1]<=.75 for q in projections[8:]))
            if good: break
            radius*=1.23
        assert good, (d,yaw,radius,projections)
        checks+=1
print('PASS: camera focus shifted downward 0.90m; elevation 0.11; close radius 7.8m')
print('PASS: bottom 25% reserved by target/player vertical fit checks')
print('PASS: all gesture, step, attack, camera-yaw, collision and FX code preserved')
print('PASS: %d independent projection sanity samples with zoom-out safety' % checks)
print('NOTE: static source/projection tests only; Godot runtime and device not tested')
