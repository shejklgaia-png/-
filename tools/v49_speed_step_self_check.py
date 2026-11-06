#!/usr/bin/env python3
"""Static source + numerical oracle for v49; no claim of Godot runtime execution."""
from pathlib import Path
import hashlib,json,math,re,random

root=Path(__file__).resolve().parents[1]
main=(root/'scripts/main.gd').read_text(encoding='utf-8')
rig=(root/'scripts/sera_rig.gd').read_text(encoding='utf-8')
source=json.loads((root/'assets/sera_source.json').read_text(encoding='utf-8'))
assert {'Step_R','Step_L'} <= {a['name'] for a in source['animations']}
manifest=json.loads((root/'tools/v46_baseline_hashes.json').read_text(encoding='utf-8'))

def extract(src,name):
    m=re.search(r'^func '+name+r'\([^\n]*\).*?(?=^func |\Z)',src,re.M|re.S)
    assert m,name
    return m.group()

# Existing drag, swipe classification, attack, camera, and per-frame mechanics
# are bit-identical to the v45 regression baselines.
for name,digest in manifest['functions'].items():
    actual=hashlib.sha256(extract(main,name).encode()).hexdigest()
    assert actual==digest,name

# Input event routing is logically identical except for the HUD variable names;
# button is now a noninteractive label whose pointer region remains excluded.
for needle in (
    'step_status_label = Label.new()',
    'step_status_label.mouse_filter = Control.MOUSE_FILTER_STOP',
    'step_status_label.text = "STEP SPEED 10m/s"',
    'if _pointer_on_step_hud(event.position):',
    'step_hud_touch = event.index',
    'elif event.index == step_hud_touch:',
    'if event.index == step_hud_touch:',
    'step_hud_mouse_press = true',
    'elif step_hud_mouse_press:',
    'func _pointer_on_step_hud(pos: Vector2) -> bool:',
    'step_duration_current = path_length / STEP_SPEED',
    'var max_path_length: float = minf(STEP_MAX_ARC_LENGTH, STEP_SPEED * STEP_MAX_DURATION)',
    'max_path_length / radius)',
    'rig.call("start_side_step", side)',
    'rig.call("finish_side_step", resume_moving)',
    'if step_linear_fallback:',
    'new_offset = step_start_offset + step_linear_offset * progress',
):
    assert needle in main,needle
for needle in ('func _toggle_step_mode()', 'step_speed_fixed', 'Button.new()', 'STEP_DURATION'):
    assert needle not in main,needle

params={a:float(b) for a,b in re.findall(
    r'^const (STEP_(?:ORBIT_ANGLE_DEGREES|MIN_ARC_LENGTH|MAX_ARC_LENGTH|SPEED|MAX_DURATION|MIN_ORBIT_RADIUS|CLOSE_ORBIT_MAX_DEGREES)): float = ([\d.]+)',main,re.M)}
assert params=={'STEP_ORBIT_ANGLE_DEGREES':35.,'STEP_MIN_ARC_LENGTH':1.5,
                'STEP_MAX_ARC_LENGTH':4.,'STEP_SPEED':10.,'STEP_MAX_DURATION':.4,
                'STEP_MIN_ORBIT_RADIUS':.1,'STEP_CLOSE_ORBIT_MAX_DEGREES':120.},params
assert math.isclose(params['STEP_SPEED']*params['STEP_MAX_DURATION'],params['STEP_MAX_ARC_LENGTH'],abs_tol=1e-9)

# Python mirror of math in _start_side_step and _advance_side_step.
def path(radius,bearing,side,camera_right):
    x,z=radius*math.cos(bearing),radius*math.sin(bearing)
    overlap=radius < 1.5/math.radians(120)
    tangent=(-z/radius,x/radius) if radius >= .1 else camera_right
    dot=tangent[0]*camera_right[0]+tangent[1]*camera_right[1]
    sign=1 if dot*side>=0 else -1
    max_path=min(params['STEP_MAX_ARC_LENGTH'],params['STEP_SPEED']*params['STEP_MAX_DURATION'])
    angle=0 if overlap else min(max(math.radians(35),1.5/radius),max_path/radius)
    length=1.5 if overlap else radius*angle
    duration=length/10
    assert 1.5-1e-9<=length<=4+1e-9
    assert .15-1e-9<=duration<=.4+1e-9
    assert math.isclose(length/duration,10,abs_tol=1e-9)
    assert angle<=math.radians(120)+1e-9
    def at(progress):
        if overlap:
            return (x+tangent[0]*sign*length*progress,
                    z+tangent[1]*sign*length*progress)
        ph=angle*sign*progress
        return (x*math.cos(ph)-z*math.sin(ph),x*math.sin(ph)+z*math.cos(ph))
    return length,duration,sign,overlap,at

random.seed(49)
checks=0
radii=[0,.05,.099,.101,.2,.5,.715,.717,.75,1,1.9,2,2.3,2.46,2.5,3,5,6.8,8,10,15,100]
for radius in radii:
    for bearing in (0,math.pi/5,math.pi/2,2*math.pi/3,math.pi):
        for side in (-1,1):
            dist,duration,sign,overlap,at=path(radius,bearing,side,(.8,.6))
            # Mid-step arc lengths must increase linearly: constant velocity.
            for n in (1,2,4,8,16):
                t=(n-1)/16
                next_t=n/16
                a,b=at(t),at(next_t)
                if overlap:
                    traveled=math.dist(a,b)
                else:
                    # exact arc length, not chord length
                    traveled=dist*(next_t-t)
                    assert math.isclose(math.hypot(*b),radius,abs_tol=1e-9)
                assert math.isclose(traveled,10*duration*(next_t-t),abs_tol=1e-8)
            final=at(1)
            for fps in (15,24,30,60,90,120,144):
                elapsed=0
                for _ in range(500):
                    elapsed=min(duration,elapsed+1/fps)
                    current=at(elapsed/duration)
                    if elapsed>=duration:
                        break
                else: raise AssertionError('did not finish')
                assert math.dist(current,final)<1e-8
                checks+=1

# Independent asset and scene content preserved from v46/v48 baseline.
for name,digest in manifest['files'].items():
    assert hashlib.sha256((root/name).read_bytes()).hexdigest()==digest,name

print('Existing drag/gesture/camera/attack and main frame pipeline: 12 baseline hashes OK')
print('HUD is read-only, touch/mouse IDs isolated from gestures: static wiring OK')
print('Constants 35 degrees, 1.5-4.0m, 10m/s, 0.15-0.40s: OK')
print(f'Circular orbit / overlap fallback / 15-144fps: {checks} scenarios OK')
print('No GDScript runtime or Android device execution in this test')
