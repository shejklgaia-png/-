#!/usr/bin/env python3
"""SERA v56: static camera/HUD/gameplay diff and geometric framing simulation."""
from pathlib import Path
import hashlib, math, re
root=Path(__file__).resolve().parents[1]
base=root.parent/'sera_portrait_godot_melee_v55_compact_hud_lower_camera'
main=(root/'scripts/main.gd').read_text(encoding='utf-8')
old=(base/'scripts/main.gd').read_text(encoding='utf-8')
constants={k:float(v) for k,v in re.findall(r'^const (\w+): float = ([\d.]+)',main,re.M)}
assert constants['CAMERA_ELEVATION_RATIO']==0.21
assert math.isclose(math.degrees(math.atan(constants['CAMERA_ELEVATION_RATIO'])),11.859779120947978)
assert constants['CAMERA_FOCUS_DROP']==1.35
assert constants['CAMERA_CLOSE_RADIUS']==7.8
assert constants['CAMERA_BASE_RADIUS']==16.0
assert constants['SCREEN_MARGIN_TOP']==.145
assert constants['SCREEN_MARGIN_BOTTOM']==.75
for key,value in [('STEP_MIN_ARC_LENGTH',2),('STEP_MAX_ARC_LENGTH',4),('STEP_CLOSE_SPEED',6),('STEP_SPEED',10),('STEP_MAX_DURATION',.4)]:
    assert constants[key]==value,(key,constants[key])
# Only comment and the elevation constant may differ in the gameplay script.
restored=main.replace("const CAMERA_ELEVATION_RATIO: float = 0.21  # v56: slightly stronger bird's-eye pitch (11.9 degrees vs 7.5 degrees).",
                      'const CAMERA_ELEVATION_RATIO: float = 0.1325  # v53: restore the v51 overhead viewing angle.')
restored=restored.replace('\n## v56: slightly increase camera overhead angle while keeping v55 focus, zoom and HUD limits.','')
assert restored==old, 'unexpected changed gameplay/HUD script content'
for name in ('scripts/touch_overlay.gd','scripts/sera_rig.gd','scenes/main.tscn'):
    assert (root/name).read_bytes()==(base/name).read_bytes(),name
for folder in ('assets','blockbench','shaders'):
    for f in (base/folder).rglob('*'):
        if f.is_file():
            q=root/f.relative_to(base)
            assert q.exists() and hashlib.sha256(q.read_bytes()).digest()==hashlib.sha256(f.read_bytes()).digest(),str(f)
print('PASS: only camera elevation constant changed; HUD, gameplay, assets unchanged')

# Perspective projection: same model as v55 test. Radius expands as required.
vertical=math.tan(math.radians(61/2))
horizontal=vertical*720/1280

def projected(p,r,yaw):
    e=constants['CAMERA_ELEVATION_RATIO']; n=math.sqrt(1+e*e)
    focus=(0,1.53-constants['CAMERA_FOCUS_DROP'],0)
    cp=(math.sin(yaw)*r,focus[1]+e*r,math.cos(yaw)*r)
    v=[p[i]-cp[i] for i in range(3)]
    right=(math.cos(yaw),0,-math.sin(yaw))
    up=(-e*math.sin(yaw)/n,1/n,-e*math.cos(yaw)/n)
    forward=(-math.sin(yaw)/n,-e/n,-math.cos(yaw)/n)
    z=sum(v[i]*forward[i] for i in range(3))
    if z<1e-5:return None
    x=sum(v[i]*right[i] for i in range(3))
    y=sum(v[i]*up[i] for i in range(3))
    return (.5+x/(2*z*horizontal), .5-y/(2*z*vertical))

n_test=0
max_radius=0
for distance in (1.5,2,3,5,8,12):
    for yaw in (-.65,-.3,0,.3,.65):
        radius=max(7.8,distance+2)
        corners=[(x,1.53+y,z) for x in (-1,1) for y in (-1,1) for z in (-1,1)]
        player=[(0,.08,distance),(0,1.85,distance)]
        for attempt in range(60):
            points=[projected(pt,radius,yaw) for pt in corners+player]
            safe=(all(v is not None for v in points)
                  and all(.025<=v[0]<=.975 and .145<=v[1]<=.75 for v in points[:8])
                  and all(.02<=v[0]<=.98 and .145<=v[1]<=.75 for v in points[8:]))
            if safe:break
            radius*=1.2
        assert safe,(distance,yaw,radius,points)
        n_test+=1
        max_radius=max(max_radius,radius)
print(f'PASS: {n_test} camera framing scenarios satisfy HUD top 14.5% and bottom 25% bounds after zoom (up to {max_radius:.2f}m)')
print('NOTE: engine/runtime/Android rendering were not tested.')
