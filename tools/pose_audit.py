#!/usr/bin/env python3
"""Independent, dependency-free pose/loop audit for Blockbench animation data.
This tests the exported keyframe math, not rendering or Godot runtime behavior.
"""
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
data = json.loads((ROOT / 'assets' / 'sera_source.json').read_text())
rig = (ROOT / 'scripts' / 'sera_rig.gd').read_text()
assert 'Quaternion(Vector3.BACK, z)' in rig
assert 'Quaternion(Vector3.UP, y)' in rig
assert 'Quaternion(Vector3.RIGHT, x)' in rig
assert '_rotation_at(rotation_values, t)' in rig
assert 'a.slerp(b, factor)' in rig

# Hamilton product, rotation order Rz * Ry * Rx.
def mul(a, b):
    x1,y1,z1,w1=a; x2,y2,z2,w2=b
    return (w1*x2+x1*w2+y1*z2-z1*y2,
            w1*y2-x1*z2+y1*w2+z1*x2,
            w1*z2+x1*y2-y1*x2+z1*w2,
            w1*w2-x1*x2-y1*y2-z1*z2)

def quat(v):
    x,y,z=[math.radians(float(v[axis])%360) for axis in ('x','y','z')]
    qx=(math.sin(x/2),0,0,math.cos(x/2))
    qy=(0,math.sin(y/2),0,math.cos(y/2))
    qz=(0,0,math.sin(z/2),math.cos(z/2))
    q=mul(mul(qz,qy),qx)
    norm=math.sqrt(sum(v*v for v in q))
    return tuple(v/norm for v in q)

def slerp(a,b,t):
    d=sum(x*y for x,y in zip(a,b))
    if d<0:
        b=tuple(-v for v in b)
        d=-d
    d=min(1.,max(-1.,d))
    if d > .9995:
        q=tuple((1-t)*x+t*y for x,y in zip(a,b))
    else:
        angle=math.acos(d)
        factor=math.sin(angle)
        q=tuple((math.sin((1-t)*angle)*x+math.sin(t*angle)*y)/factor for x,y in zip(a,b))
    norm=math.sqrt(sum(v*v for v in q))
    return tuple(v/norm for v in q)

def sample(frames,t):
    frames=sorted(frames,key=lambda frame:frame['time'])
    keys=[(float(f['time']),quat(f['data_points'][0])) for f in frames]
    if t <= keys[0][0]:return keys[0][1]
    for i in range(1,len(keys)):
        if t <= keys[i][0]:
            start,a=keys[i-1];end,b=keys[i]
            return slerp(a,b,(t-start)/(end-start))
    return keys[-1][1]

def angular_distance(a,b):
    dot=abs(sum(x*y for x,y in zip(a,b)))
    return math.degrees(2*math.acos(min(1.,max(-1.,dot))))

# Sanity: multi-turn values must not cause different orientations.
assert angular_distance(quat({'x':'-720','y':'-85','z':'-707.5'}),quat({'x':'0','y':'-85','z':'12.5'}))<1e-4

for clip in data['animations']:
    if clip['name'] not in ('Wait_motion','run_front_original'):continue
    length=clip['length'];max_step=0.0;max_bone='';ntracks=0
    for uid,animator in clip['animators'].items():
        frames=[f for f in animator.get('keyframes',[]) if f.get('channel')=='rotation']
        if not frames:continue
        ntracks+=1
        begin=sample(frames,0)
        end=sample(frames,length)
        assert angular_distance(begin,end)<1e-3,(clip['name'],uid,'loop mismatch')
        samples=[sample(frames,length*i/600.0) for i in range(601)]
        for a,b in zip(samples,samples[1:]):
            d=angular_distance(a,b)
            if d>max_step: max_step=d;max_bone=uid
            assert math.isfinite(d)
    print(f"{clip['name']}: {ntracks} rotation tracks, loop closure OK, maximum 1/600-cycle change {max_step:.2f} deg ({max_bone[:8]})")
print('Pose interpolation audit PASSED (not a Godot runtime test)')
