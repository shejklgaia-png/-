#!/usr/bin/env python3
"""Static / pinhole-projection regression tests for SERA v55. Not runtime rendering."""
from pathlib import Path
import hashlib,re,math,difflib
root=Path(__file__).resolve().parents[1]
base=root.parent/'sera_portrait_godot_melee_v54_target_marker_follow'
main=(root/'scripts/main.gd').read_text(encoding='utf-8')
old=(base/'scripts/main.gd').read_text(encoding='utf-8')
overlay=(root/'scripts/touch_overlay.gd').read_text(encoding='utf-8')
oldoverlay=(base/'scripts/touch_overlay.gd').read_text(encoding='utf-8')
constants={key:float(num) for key,num in re.findall(r'^const (\w+): float = ([\d.]+)',main,re.M)}
prior={key:float(num) for key,num in re.findall(r'^const (\w+): float = ([\d.]+)',old,re.M)}
expected={'CAMERA_ELEVATION_RATIO':0.1325,'CAMERA_FOCUS_DROP':1.35,'CAMERA_CLOSE_RADIUS':7.8,'CAMERA_BASE_RADIUS':16.0,'SCREEN_MARGIN_TOP':.145,'SCREEN_MARGIN_BOTTOM':.75,'TARGET_FRAME_MARGIN_Y':.145,'TARGET_FRAME_BOTTOM':.75,'STEP_MIN_ARC_LENGTH':2.0,'STEP_MAX_ARC_LENGTH':4.0,'STEP_CLOSE_SPEED':6.0,'STEP_SPEED':10.0,'STEP_MAX_DURATION':.40}
for k,v in expected.items(): assert abs(constants[k]-v)<1e-8,(k,constants[k])
assert constants['CAMERA_ELEVATION_RATIO']==prior['CAMERA_ELEVATION_RATIO']
assert math.isclose(math.atan(constants['CAMERA_ELEVATION_RATIO']),math.atan(prior['CAMERA_ELEVATION_RATIO']))
for k in ('CAMERA_CLOSE_RADIUS','CAMERA_BASE_RADIUS','STEP_MIN_ARC_LENGTH','STEP_MAX_ARC_LENGTH','STEP_SPEED','STEP_CLOSE_SPEED','STEP_CLOSE_DISTANCE','STEP_MAX_DURATION','SCREEN_MARGIN_BOTTOM','TARGET_FRAME_BOTTOM'):
    assert constants[k]==prior[k],(k,constants[k],prior[k])
# HUD top area is <= 150/1280=11.72%; no lower instruction drawing.
assert 'hud_panel.offset_top = 26.0' in main and 'hud_panel.offset_bottom = 150.0' in main
assert 'hud_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)' in main
assert main.count('set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)')==3
assert '"TAP   /   DRAG   /   FLICK"' in main
assert 'draw_string(font' not in overlay
assert 'func _pointer_on_step_hud(pos: Vector2)' in main
assert 'hud_panel.get_global_rect().has_point(pos)' in main
assert '_update_target_marker_projection()' in main
assert 'camera.unproject_position(center_world)' in main
assert 'hp_fill.size = Vector2(300.0 * float(target_hp) / float(TARGET_MAX_HP), 7.0)' in main
assert 'camera.look_at(focus, Vector3.UP)' in main
assert 'CAMERA_ELEVATION_RATIO * camera_radius' in main
# Only expected functions change; input, step, collision and target-following marker untouched.
def funcs(s):
    return {m.group(1):m.group(0) for m in re.finditer(r'^func (\w+)\([^\n]*\)[\s\S]*?(?=^func |\Z)',s,re.M)}
a,b=funcs(main),funcs(old)
assert a.keys()==b.keys()
changed={k for k in a if a[k]!=b[k]}
assert changed=={'_build_overlay','_refresh_hp_bar','_pointer_on_step_hud'}, changed
# Confirm only touch-overlay's last else drawing and a comment changed.
assert '_draw()' in oldoverlay and 'draw_arc(mark' in overlay
for folder in ['assets','blockbench','scenes','shaders','scripts']:
    for p in (base/folder).rglob('*'):
        if p.is_file() and p.name not in ('main.gd','touch_overlay.gd'):
            new=root/p.relative_to(base)
            assert new.is_file() and hashlib.sha256(p.read_bytes()).digest()==hashlib.sha256(new.read_bytes()).digest(),p
print('PASS: unchanged gameplay/collision/motion/marker/assets, except HUD and camera constants')

# Independent perspective projection of target corners and player body against HUD exclusion.
vertical=math.tan(math.radians(61/2))
horizontal=vertical*720/1280

def projected(p,r,yaw,px,pz,target_x=0,target_z=0):
    e=constants['CAMERA_ELEVATION_RATIO']; n=math.sqrt(1+e*e)
    focus=(target_x,1.53-constants['CAMERA_FOCUS_DROP'],target_z)
    cp=(focus[0]+math.sin(yaw)*r,focus[1]+e*r,focus[2]+math.cos(yaw)*r)
    v=[p[i]-cp[i] for i in range(3)]
    right=(math.cos(yaw),0,-math.sin(yaw))
    up=(-e*math.sin(yaw)/n,1/n,-e*math.cos(yaw)/n)
    forward=(-math.sin(yaw)/n,-e/n,-math.cos(yaw)/n)
    z=sum(v[i]*forward[i] for i in range(3))
    if z<1e-5:return None
    x=sum(v[i]*right[i] for i in range(3))
    y=sum(v[i]*up[i] for i in range(3))
    return (.5+x/(2*z*horizontal), .5-y/(2*z*vertical))

checks=0
for distance in (1.5,2,3,5,8,12):
    for yaw in (-.65,-.3,0,.3,.65):
        radius=max(7.8,distance+2)
        target_pts=[(x,1.53+y,z) for x in (-1,1) for y in (-1,1) for z in (-1,1)]
        player_pts=[(0,.08,distance),(0,1.85,distance)]
        for t in range(60):
            points=[projected(q,radius,yaw,0,distance) for q in target_pts+player_pts]
            valid=(all(q is not None for q in points)
                   and all(.025<=q[0]<=.975 and .145<=q[1]<=.75 for q in points[:8])
                   and all(.02<=q[0]<=.98 and .145<=q[1]<=.75 for q in points[8:]))
            if valid:break
            radius*=1.2
        assert valid,(distance,yaw,radius,points)
        checks+=1
print(f'PASS: {checks} close/far/yaw projection tests fit above lower-25% and below top HUD (zoom when needed)')
print('NOTE: Static geometry-only; engine and device rendering not executed.')
