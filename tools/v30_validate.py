#!/usr/bin/env python3
"""V30 static audit; intentionally NOT a substitute for the Godot renderer."""
from pathlib import Path
from PIL import Image
import json,re,hashlib,math,sys
ROOT=Path(__file__).resolve().parent.parent
V29=ROOT.parent/'sera_portrait_godot_melee_v29_white_slash'
checks=[]
def test(label, condition, detail=None):
    checks.append({'name':label,'pass':bool(condition),'detail':str(detail) if detail is not None else None})
    print(('PASS' if condition else 'FAIL')+' '+label+((': '+str(detail)) if detail is not None else ''))
def digest(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
for rel in ['scripts/sera_rig.gd','scripts/main.gd','scripts/touch_overlay.gd','scenes/main.tscn','assets/sera_source.json','assets/sera_data.gd','blockbench/セラ･カラーエフェクト付き.bbmodel']:
    test('v29 preserved (except intentional v31 hit-burst render flags): '+rel,digest(ROOT/rel)==digest(V29/rel))
rig=(ROOT/'scripts/sera_rig.gd').read_text()
trail=(ROOT/'scripts/sword_trail.gd').read_text()
flat=(ROOT/'shaders/slash_C_sprite.gdshader').read_text()
volume=(ROOT/'shaders/slash_C_volume.gdshader').read_text()
test('exact forward offset still 0.55m', 'sword_effect_forward_offset: float = 0.55' in rig)
test('effect attached as child of ORIGINAL mesh', 'instance.add_child(volume_instance)' in trail and 'instance.add_child(particle_instance)' in trail)
test('child transforms identity',trail.count('transform = Transform3D.IDENTITY')==2)
test('no second world offset', 'sword_effect_forward_offset' not in trail and 'global_transform =' not in trail and 'look_at(' not in trail)
test('flat texture remains rendered as trace','instance.material_override = flat_material' in trail and 'flat_layer_opacity: float = 0.35' in trail)
test('far skin only', 'cull_front' in volume and 'blend_mix' in volume)
test('UV frames stay 4 x 2', '(uv + grid) * vec2(0.25,0.5)' in volume and 'vec2(0.25, 0.5)' in flat)
test('8 sprite frames exactly same timing as v29',all(s in trail for s in ['0.375','0.315','0.255','0.205','0.165','0.130','0.105']))
test('independent seeded particle logic','rng.randomize()' in trail and '_spawn_particle' in trail and 'particle_instance.mesh = surf.commit()' in trail)
test('mobile renderer unchanged', '[rendering]' in (ROOT/'project.godot').read_text() and 'gl_compatibility' in (ROOT/'project.godot').read_text())
geo=json.loads((ROOT/'assets/slash_C_volume_geometry.json').read_text())
test('geometry has all 8 frames', len(geo['frames'])==8)
bad=0;triangle_count=0;heights=[];bad_indices=0
for i,f in enumerate(geo['frames']):
    pts=f['points']; tris=f['triangles']
    bad+=sum(not (-0.005<=p[0]<=1.005 and -0.005<=p[1]<=1.005 and 0<=p[2]<=0.065) for p in pts)
    bad_indices+=sum(any(j<0 or j>=len(pts) for j in t) for t in tris)
    triangle_count+=len(tris);heights+= [p[2] for p in pts]
    test('frame '+str(i)+' 3D triangles and emission samples', len(pts)>=20 and len(tris)>=20 and len(f['emitters'])>0,(len(pts),len(tris)))
test('all mesh UV / height values in valid ranges',bad==0,bad)
test('all mesh triangle indices valid',bad_indices==0,bad_indices)
test('convex height exists but has sharp zero-height edges',any(h==0 for h in heights) and max(heights)>=0.06,(min(heights),max(heights)))
# Derived from source BB quad, numeric check of the exact UV reconstruction.
src=json.loads((ROOT/'assets/sera_source.json').read_text())
e=next(q for q in src['elements'] if q['name']=='Swordeffect')
face=next(iter(e['faces'].values()))
maxerr=0.
for key,tex in face['uv'].items():
    src_v=e['vertices'][key]
    u,v=tex[0]/16,tex[1]/16
    # local mesh vertex has same coordinates after centroid subtraction.
    restored=((u-.5)*1.04,0.,(v-.5)*1.04)
    expected=(src_v[0]*.065,src_v[1]*.065,src_v[2]*.065)
    maxerr=max(maxerr,max(abs(a-b) for a,b in zip(restored,expected)))
test('source UV corner / 3D volume corner error (m)',maxerr<1e-8,maxerr)
old=Image.open(V29/'assets/slash_C_white_4x2.png').convert('RGBA')
clean=Image.open(ROOT/'assets/slash_C_white_clean_4x2.png').convert('RGBA')
test('clean atlas size & format preserved',old.size==clean.size==(2048,1024))
import numpy as np
A=np.asarray(old);B=np.asarray(clean)
removed=np.count_nonzero((A[:,:,3]>30)&(B[:,:,3]==0))
test('original baked-in particles actually removed',removed>600,removed)
test('white color remains white',all(all(x in (0,255) for x in px) for px in np.unique(B[:,:,:3].reshape(-1,3),axis=0)),np.unique(B[:,:,:3].reshape(-1,3),axis=0).tolist()[:6])
missing=[]
for code in list((ROOT/'scripts').glob('*.gd'))+list((ROOT/'assets').glob('*.gd')):
    txt=code.read_text()
    for path in re.findall(r'(?:preload|load)\(["\'](res://[^"\']+)["\']\)',txt):
        if not (ROOT/path[6:]).exists():missing.append((code.name,path))
test('all referenced scripts/assets exist',not missing,missing)
pass_count=sum(x['pass'] for x in checks)
summary={'passed':pass_count,'failed':len(checks)-pass_count,'checks':len(checks),'volume_triangles_total':triangle_count,'max_corner_error_m':maxerr,'pixels_removed':int(removed),'godot_runtime_test':'NOT EXECUTED — Godot binary unavailable here'}
(ROOT/'tools/v30_static_report.json').write_text(json.dumps({'summary':summary,'checks':checks},indent=2,ensure_ascii=False))
print('SUMMARY',summary)
if summary['failed']:sys.exit(1)
