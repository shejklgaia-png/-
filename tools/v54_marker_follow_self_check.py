#!/usr/bin/env python3
"""v54 static + numerical marker projection regression. NOT Godot runtime execution."""
from pathlib import Path
import hashlib, math, re

root=Path(__file__).resolve().parents[1]
base=root.parent/'sera_portrait_godot_melee_v53_original_pitch_step2m'
main=(root/'scripts/main.gd').read_text(encoding='utf-8')
ui=(root/'scripts/touch_overlay.gd').read_text(encoding='utf-8')
orig_main=(base/'scripts/main.gd').read_text(encoding='utf-8')
orig_ui=(base/'scripts/touch_overlay.gd').read_text(encoding='utf-8')

def functions(src):
    return {m.group(1):m.group(0) for m in re.finditer(r'^func (\w+)\([^\n]*\)[\s\S]*?(?=^func |\Z)',src,re.M)}

old,now=functions(orig_main),functions(main)
assert set(now)==set(old)|{'_update_target_marker_projection'}
expected_ready=old['_ready'].replace('    _build_hit_effects()\n',
    '    _build_hit_effects()\n    _update_target_marker_projection()  # Initial position before the first rendered frame.\n')
assert now['_ready']==expected_ready
expected_proc=old['_process'].replace('''    if hit_stop_remaining > 0.0:
        return  # Hold target bob and camera for the impact beat.
''','''    if hit_stop_remaining > 0.0:
        _update_target_marker_projection()  # Still track externally moving targets during hit-stop.
        return  # Hold target bob and camera for the impact beat.
''').replace('''    was_running = running
''','''    was_running = running
    # Always project AFTER the camera's yaw / zoom / framing corrections.
    # This follows both camera movement and a target whose world position changes.
    _update_target_marker_projection()
''')
assert now['_process']==expected_proc
for name in old:
    if name not in ('_ready','_process'):
        assert now[name]==old[name],f'Changed unapproved main function: {name}'
assert main.count('func _update_target_marker_projection() -> void:')==1
assert 'camera.unproject_position(center_world)' in now['_update_target_marker_projection']
assert 'var center_world: Vector3 = target.global_position' in now['_update_target_marker_projection']
assert 'camera.is_position_behind(center_world)' in now['_update_target_marker_projection']
assert 'screen_position.x <= viewport_size.x' in now['_update_target_marker_projection']
assert 'screen_position.y <= viewport_size.y' in now['_update_target_marker_projection']
assert now['_process'].rfind('_update_target_marker_projection()') > now['_process'].rfind('_fit_full_frame()')

u_old,u_now=functions(orig_ui),functions(ui)
assert set(u_now)==set(u_old)|{'set_target_marker_projection'}
for name in u_old:
    if name!='_draw': assert u_old[name]==u_now[name],f'Changed overlay function: {name}'
assert 'var mark: Vector2 = target_marker_position' in u_now['_draw']
assert 'draw_arc(mark, lock_radius' in u_now['_draw']
assert u_now['_draw'].count('draw_line(mark +')==4
assert 'if target_marker_visible:' in u_now['_draw']
assert 'draw_circle(anchor_point, radius' in u_now['_draw'], 'drag must remain available'
assert 'draw_string(font,' in u_now['_draw'], 'non-drag instructions remain'
assert 'target_marker_position.is_equal_approx(screen_position)' in u_now['set_target_marker_projection']
assert 'queue_redraw()' in u_now['set_target_marker_projection']
assert 'mouse_filter = Control.MOUSE_FILTER_IGNORE' in main

# All other assets, animation, combat and collision scripts unchanged.
exclude={'scripts/main.gd','scripts/touch_overlay.gd','project.godot','README_ja.md'}
orig_files={str(f.relative_to(base)):hashlib.sha256(f.read_bytes()).hexdigest()
            for f in base.rglob('*') if f.is_file() and str(f.relative_to(base)) not in exclude}
new_files={str(f.relative_to(root)):hashlib.sha256(f.read_bytes()).hexdigest()
           for f in root.rglob('*') if f.is_file() and str(f.relative_to(root)) not in exclude
           and not f.name.startswith('v54_') and f.name!='README_v54_ja.md'}
assert orig_files==new_files,'Unintended modified/removed project assets or older test files'

# Independent pinhole projection check, including moving target and a changing camera.
# Analytic camera matches the established v53 camera (61 degree vertical FOV).
viewport=(720.,1280.)
tan_v=math.tan(math.radians(61/2))
tan_h=tan_v*viewport[0]/viewport[1]

def projection(target, radius, yaw, elevation=.1325, focus_drop=.90):
    sy,cy=math.sin(yaw),math.cos(yaw)
    n=math.sqrt(1+elevation*elevation)
    focus_y=target[1]-focus_drop
    cam=(target[0]+radius*sy, focus_y+elevation*radius, target[2]+radius*cy)
    v=tuple(target[i]-cam[i] for i in range(3))
    right=(cy,0.,-sy)
    up=(-elevation*sy/n,1/n,-elevation*cy/n)
    fw=(-sy/n,-elevation/n,-cy/n)
    z=sum(v[i]*fw[i] for i in range(3))
    if z<=0: return None
    x=sum(v[i]*right[i] for i in range(3))
    y=sum(v[i]*up[i] for i in range(3))
    return (viewport[0]*(.5+x/(2*z*tan_h)),viewport[1]*(.5-y/(2*z*tan_v)))

samples=0
for center in [(0.,1.53,-8.),(1.,1.1,-7.),(-3.,1.6,-5.),(2.,1.0,4.)]:
    for radius in [7.8,9.,16.,24.]:
        for yaw in [-2.,-.5,0.,.6,1.8]:
            projected=projection(center,radius,yaw)
            assert projected is not None
            assert all(math.isfinite(t) for t in projected)
            # This target-center-relative camera should always project the
            # reticle to the same above-center location regardless of target XZ.
            if center[0]!=0 or center[2]!=-8:
                reference=projection((0.,1.53,-8.),radius,yaw)
                assert all(abs(a-b)<1e-7 for a,b in zip(projected,reference))
            # With v52's lowered focus, the target should appear above screen center.
            assert projected[1] < viewport[1]*.5
            samples+=1

# An independently translated target under a *stationary* camera must shift
# the marker, not stay at screen center. Projection depends on world position.
def static_camera_projection(world,cam=(0.,3.5,10.),fov=61.0):
    # yaw=0, horizontal perspective, forward toward -Z; sufficient for delta test.
    x,y,z=(world[i]-cam[i] for i in range(3))
    depth=-z
    assert depth>0
    return (viewport[0]*(.5+x/(2*depth*tan_h)),viewport[1]*(.5-y/(2*depth*tan_v)))

p0=static_camera_projection((0,1.53,-8))
px=static_camera_projection((3,1.53,-8))
py=static_camera_projection((0,2.53,-8))
pz=static_camera_projection((0,1.53,-5))
assert px[0]>p0[0] and abs(px[1]-p0[1])<1e-7
assert py[1]<p0[1] and abs(py[0]-p0[0])<1e-7
assert pz!=p0
print(f'PASS: {len(old)} preexisting main functions unaffected except expected wiring, {len(u_old)} overlay functions unaffected except marker draw')
print(f'PASS: {len(orig_files)} existing project files preserved byte-for-byte')
print(f'PASS: {samples} camera-relative projections and stationary-camera target translation checks')
print('NOTE: static / analytic only; no Godot runtime or Android device test.')
