#!/usr/bin/env python3
"""Static integrity checks for v27; does NOT emulate Godot's renderer."""
from pathlib import Path
import json,re,hashlib
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
BASE=Path(__file__).resolve().parents[2]/'work'/'sera_portrait_godot_melee_v26'
checks=[]
def check(name, ok, detail=''):
 checks.append((name,bool(ok),detail))
 print(('PASS' if ok else 'FAIL')+' | '+name+(' | '+str(detail) if detail else ''))

data=json.loads((ROOT/'assets/sera_source.json').read_text(encoding='utf8'))
effects=[e for e in data['elements'] if e['name']=='Swordeffect']
check('Effect mesh is unique',len(effects)==1)
e=effects[0]
check('One authored quad / four vertices / one face', len(e['vertices'])==4 and len(e['faces'])==1)
verts=next(iter(e['faces'].values()))
coords=list(verts['uv'].values())
check('UV square maps exactly [0..16]',sorted(set(round(float(v[0]),3) for v in coords))==[0,16] and sorted(set(round(float(v[1]),3) for v in coords))==[0,16])
by_uuid={g['uuid']:g for g in data['groups']}
par=[]
def walk(entries,parent=None):
 for item in entries:
  if isinstance(item,dict): walk(item.get('children',[]), item.get('uuid'))
  elif item==e['uuid']: par.append(parent)
walk(data['outliner'])
check('Effect attached under separate root bone',len(par)==1 and by_uuid[par[0]]['name']=='Swordeffect')
melee=next(a for a in data['animations'] if a['name']=='melee1')
keys=melee['animators'][par[0]]['keyframes']
check('Position/rotation/scale keyframes preserved',sorted([x['channel'] for x in keys])==['position','rotation','scale'])
scale=next(x for x in keys if x['channel']=='scale')['data_points'][0]
check('User-authored XY/Z scale values unchanged', abs(float(scale['x'])-3.63)<1e-6 and abs(float(scale['z'])-4.02)<1e-6)
for pal in ['ice','scarlet']:
 fn=ROOT/f'assets/slash_C_{pal}_4x2.png';im=Image.open(fn)
 check(f'{pal} atlas format & size',im.mode=='RGBA' and im.size==(2048,1024))
 count=0
 for i in range(8):
  sub=im.crop(((i%4)*512,(i//4)*512,((i%4)+1)*512,((i//4)+1)*512))
  if sub.getchannel('A').getbbox(): count+=1
 check(f'{pal} all 8 frames nonempty',count==8)
shader=(ROOT/'shaders/slash_C_sprite.gdshader').read_text()
check('Sprite UV shader reads frame index', 'frame_index % 4' in shader and 'frame_index / 4' in shader)
rig=(ROOT/'scripts/sera_rig.gd').read_text()
check('Rig reads BB scale track', '"scale": []' in rig and 'bone.scale = scale_value' in rig)
check('Rig normalizes effect UV', 'if is_sword_fx:' in rig and '/ 16.0' in rig)
check('Rig exposes authored plane', 'func get_sword_effect_mesh()' in rig)
trail=(ROOT/'scripts/sword_trail.gd').read_text()
check('Effect renderer reuses plane instead of making geometry', 'get_sword_effect_mesh' in trail and 'QuadMesh.new' not in trail and 'global_transform =' not in trail and '.rotation =' not in trail)
check('Effect is only shown during strike', 'if not swing_running:' in trail and 'instance.visible = false' in trail)
check('Hit window still aligns with effect',float(re.search(r'STRIKE_ACTIVE_FROM: float = ([0-9.]+)',(ROOT/'scripts/main.gd').read_text()).group(1)) <= 0.165 <= float(re.search(r'STRIKE_ACTIVE_TO: float = ([0-9.]+)',(ROOT/'scripts/main.gd').read_text()).group(1)))
check('Main scene declared', (ROOT/'scenes/main.tscn').is_file() and 'scenes/main.tscn' in (ROOT/'project.godot').read_text())
script=(ROOT/'scripts/main.gd').read_text()
check('Trail binds to rig after building it', 'sword_trail.call("attach_to_rig", rig)' in script)
check('Base attack/move controls retained', 'func _end_drag()' in script and 'func _check_strike_contact()' in script and 'func _screen_drag_to_ground(' in script)
for name in ['hit_burst.gd','touch_overlay.gd']:
 f=ROOT/'scripts'/name; orig=BASE/'scripts'/name
 check(name+' unchanged from v26',orig.exists() and f.read_bytes()==orig.read_bytes())
# Check all preload/load local resources exist.
missing=[]
for code in list((ROOT/'scripts').glob('*.gd'))+list((ROOT/'assets').glob('*.gd')):
 for path in re.findall(r'(?:preload|load)\(["\'](res://[^"\']+)["\']\)',code.read_text()):
  if not (ROOT/path.replace('res://','')).exists(): missing.append((code.name,path))
check('Every preloaded local resource exists',len(missing)==0,missing)

results={'passed':sum(int(c[1]) for c in checks),'failed':sum(not c[1] for c in checks),'tests':len(checks)}
(ROOT/'tools/v27_static_report.json').write_text(json.dumps(results,indent=2))
print('SUMMARY',results)
if results['failed']: raise SystemExit(1)
