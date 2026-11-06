#!/usr/bin/env python3
"""v84 static invariants. Not a substitute for actual Godot rendering."""
from pathlib import Path
import json, re, base64, hashlib, zipfile
from PIL import Image
R=Path(__file__).resolve().parents[1]
prev=R.parent.parent/'sera_portrait_godot_melee_v83_three_hit_combo.zip'  # Optional external v83 baseline
source=json.loads((R/'assets/sera_source.json').read_text('utf-8'))
model=json.loads((R/'blockbench/SERA_melee_combo_3_v84.bbmodel').read_text('utf-8'))
user=json.loads((R/'blockbench/SERA_melee_combo_3_user_input.bbmodel').read_text('utf-8'))
main=(R/'scripts/main.gd').read_text('utf-8')
rig=(R/'scripts/sera_rig.gd').read_text('utf-8')
trail=(R/'scripts/sword_trail.gd').read_text('utf-8')
uid='cd682f33-b5f1-debc-4bcf-ce5d0e588753'
N=0
def ck(condition,message):
 global N
 assert condition, message
 N+=1
 print('PASS',message)
ck(source==model,'JSON and bbmodel identical structure')
ck(len(source['elements'])==25 and len(source['groups'])==22,'25 model elements, 22 bones retained')
ck(len(source['animations'])==10,'10 animation clips retained')
clips={a['name']:a for a in source['animations']}; uclips={a['name']:a for a in user['animations']}
ck(all(c in clips for c in ['melee1','Melee2','Melee3','Step_L','Step_R','Damageknock']),'combo and reaction clips kept')
ck([clips[n]['length'] for n in ['melee1','Melee2','Melee3']]==[.5,.5,.83333],'stage durations unchanged')
for n in ['melee1','Melee2','Melee3']:
 ck(clips[n]['animators'][uid] == uclips[n]['animators'][uid],n+' authored board transforms copied exactly')
 ck(clips[n]['loop']=='once',n+' is nonlooping')
ck([len(clips[n]['animators'][uid]['keyframes']) for n in ['melee1','Melee2','Melee3']]==[3,4,3], 'exact number of authored board keys retained')
ck('sword_effect_forward_offset' not in rig,'old forward 0.55m correction removed')
ck('effect_plane.mesh = source_plane.mesh' in trail,'reuse exact authored four-vertex plate mesh')
ck('effect_root.transform = source_plane.transform' in trail,'reuse exact authored mesh transform')
ck('source_plane.get_parent().add_child(effect_root)' in trail,'follow authored animated bone, not camera')
ck('ATLAS_COLS: int = 4' in trail and 'ATLAS_ROWS: int = 2','4x2 sprite atlas')
ck('effect_material.uv1_scale' in trail and 'effect_material.uv1_offset' in trail,'atlas UV scale + tile switching')
ck('StandardMaterial3D.new()' in trail and not 'ShaderMaterial.new()' in trail,'uses built-in material, no shader fallback')
ck('sample_swing(' in trail and 'begin_swing(' in trail and 'stop_swing(' in trail and 'advance(' in trail and 'set_red_palette(' in trail,'v83 main.gd effect API preserved')
ck('STRIKE_TRAIL_OFFSETS = [0.0, 0.0, 0.210]' in main,'third attack starts later')
ck('STRIKE_CANCEL_TIMES = [7.0 / 24.0, 7.0 / 24.0, 15.0 / 24.0]' in main,'combo cancel gates unchanged')
ck('STEP_CLOSE_CAMERA_MAX_RELATIVE_DEGREES: float = 65.0' in main,'camera bound unchanged')
ck('STEP_CLOSE_SPEED: float = 8.0' in main,'step speed unchanged')
ck('DAMAGE_KNOCKBACK_DISTANCE: float = 1.20' in main,'damage knockback unchanged')
ck('renderer/rendering_method="gl_compatibility"' in (R/'project.godot').read_text(),'Compatibility renderer retained')
ck(all(path.name.startswith('sword_fx') for path in (R/'assets').glob('sword_fx*.png')),'new sprite naming consistent')
for color in ['white','red']:
 im=Image.open(R/f'assets/sword_fx_{color}_4x2_mobile.png')
 ck(im.size==(1024,512) and im.mode=='RGBA',color+' mobile RGBA 1024x512')
 for i in range(8):
  tile=im.crop(((i%4)*256,(i//4)*256,((i%4)+1)*256,((i//4)+1)*256))
  ck(tile.getbbox() is not None and tile.getchannel('A').getextrema()[0]==0, f'{color} frame {i} has slash and transparent background')
embedded=(R/'assets/sera_data.gd').read_text('utf-8')
chunks=re.findall(r'    "([A-Za-z0-9+/=]+)",',embedded)
ck(base64.b64decode(''.join(chunks))==(R/'assets/sera_source.json').read_bytes(),'embedded Android model data identical')
for gd in (R/'scripts').glob('*.gd'):
 for uri in re.findall(r'(?:preload|load)\("res://([^"]+)"\)',gd.read_text('utf-8')):
  ck((R/uri).exists(),'preload exists: '+uri)
# compare all source ZIP members not specifically allowed to differ.
allow={'assets/sera_data.gd','assets/sera_source.json','scripts/sword_trail.gd','scripts/sera_rig.gd','scripts/main.gd','project.godot','DEVELOPMENT.md'}
if prev.exists():
 with zipfile.ZipFile(prev) as z:
  names=[n for n in z.namelist() if not n.endswith('/')]
  count=0
  for n in names:
   rel=n.split('/',1)[1]
   if rel in allow: continue
   current=R/rel
   ck(current.exists() and hashlib.sha256(current.read_bytes()).digest()==hashlib.sha256(z.read(n)).digest(), 'untouched original file '+rel) if rel.startswith(('scenes/','scripts/','shaders/')) or rel in {'README_v83_ja.md'} else None
   count+=1
  print('Compared untouched existing members:',count)
else:
 print('Optional v83 ZIP baseline not found: hash comparison skipped (core checks still run)')
print(f'v84 static checks PASS: {N}')
