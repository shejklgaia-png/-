#!/usr/bin/env python3
"""Sera v85 static and numerical checks, without Godot render/runtime claims."""
from pathlib import Path
from PIL import Image
import json, re, base64, hashlib, zipfile
R=Path(__file__).resolve().parents[1]
BASE=Path('/mnt/data/sera_portrait_godot_melee_v84_authored_sword_fx.zip')
checks=0
def ck(desc, condition):
 global checks
 assert condition, 'FAIL: '+desc
 checks+=1
 print('PASS',desc)
trail=(R/'scripts/sword_trail.gd').read_text()
main=(R/'scripts/main.gd').read_text()
rig=(R/'scripts/sera_rig.gd').read_text()
source=json.loads((R/'assets/sera_source.json').read_text())
model=json.loads((R/'blockbench/SERA_melee_combo_3_v85.bbmodel').read_text())
ck('v85 blockbench contains unchanged source model',model==source)
ck('rig respects authored transform (no forward offset)', 'sword_effect_forward_offset' not in rig and 'effect_root.transform = source_plane.transform' in trail)
ck('FX attached to actual animated Swordeffect parent','source_plane.get_parent().add_child(effect_root)' in trail)
ck('source plane only transform reference', 'source_plane.visible = false' in trail and 'effect_plane.mesh = source_plane.mesh' not in trail)
ck('3D volume and alpha-clipped arc created',all(x in trail for x in ['func _build_lens(', 'func _build_flat(', 'lens_mesh.mesh = _build_lens(frame)', 'flat_mesh.mesh = _build_flat(frame)']))
ck('extruded two-sided convex shell', 'for side in [1.0, -1.0]' in trail and 'float(p[2]) * side' in trail)
ck('transparent board pixels excluded by geometry','for cell in cutout_tiles[frame]:' in trail)
ck('particle scatter present',all(x in trail for x in ['func _step_particles(', 'func _spawn_particle(', 'func _draw_particles(', 'frame_emitters[frame]']))
ck('particle cap 32 and randomized life,size,speed',all(x in trail for x in ['MAX_PARTICLES: int = 32','rng.randf_range(0.17,0.40)','rng.randf_range(0.016,0.034)','rng.randf_range(0.16,0.60)']))
ck('particles freeze on hitstop','if not paused_for_hit_stop: _step_particles(delta, frame)' in trail)
ck('impact FX kept external','func on_hit(_world_hit: Vector3) -> void:\n    pass' in trail)
ck('8-frame animation and 3rd strike delay preserved', 'clip_time - strike_trail_offset' in trail and 'if t >= 0.375: return 7' in trail and 'STRIKE_TRAIL_OFFSETS = [0.0, 0.0, 0.210]' in main)
ck('three hit combo gate preserved','STRIKE_CLIPS = ["melee1", "Melee2", "Melee3"]' in main and 'STRIKE_CANCEL_TIMES = [7.0 / 24.0, 7.0 / 24.0, 15.0 / 24.0]' in main)
ck('original camera speed and step logic untouched','STEP_CLOSE_CAMERA_MAX_RELATIVE_DEGREES: float = 65.0' in main and 'STEP_CLOSE_SPEED: float = 8.0' in main)
ck('white/red palette switch preserved', 'set_red_palette(enabled: bool)' in trail and 'RED_FRAMES[frame]' in trail)
ck('foreground override preserved', 'set_slash_player_foreground' in trail)
ck('engine compatibility preserved','renderer/rendering_method="gl_compatibility"' in (R/'project.godot').read_text())
ck('model animation durations preserved',[(a['name'],a['length']) for a in source['animations'] if a['name'] in {'melee1','Melee2','Melee3'}]==[('melee1',0.5),('Melee2',0.5),('Melee3',0.83333)])
for n in ['melee1','Melee2','Melee3']:
 ck(n+' authored board animation retained',len(next(a for a in source['animations'] if a['name']==n)['animators']['cd682f33-b5f1-debc-4bcf-ce5d0e588753']['keyframes'])>=3)
volume=json.loads((R/'assets/slash_C_volume_geometry.json').read_text())['frames']
tiles=json.loads((R/'assets/v35_cutout_tiles.json').read_text())['frames']
ck('8 volume frames and cutouts',len(volume)==len(tiles)==8)
for i in range(8):
 frame=volume[i]
 ck('frame %d: geometry + particle source populated'%i, len(frame['points'])>=3 and len(frame['triangles'])>0 and len(frame['emitters'])>0 and len(tiles[i])>0)
 n=len(frame['points'])
 ck('frame %d: mesh indices valid'%i,all(0<=k<n for t in frame['triangles'] for k in t))
 ck('frame %d: 3D thickness exists'%i,any(p[2]>0 for p in frame['points']))
 ck('frame %d: UV point bounds'%i,all(0<=p[0]<=1 and 0<=p[1]<=1 for p in frame['points']))
for tone in ('white','red'):
 for i in range(8):
  p=R/f'assets/v35_cutout_frames/{tone}_{i}.png'; im=Image.open(p)
  ck(f'{tone} frame {i}: valid alpha cutout',im.size==(512,512) and im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0 and im.getbbox()!=None)
# Ensure every GDScript preload exists.
for gd in (R/'scripts').glob('*.gd'):
 for uri in re.findall(r'(?:preload|load)\("res://([^"]+)"\)',gd.read_text()):
  ck('resource reference '+str(gd.name)+': '+uri,(R/uri).is_file())
embedded=(R/'assets/sera_data.gd').read_text()
chunks=re.findall(r'    "([A-Za-z0-9+/=]+)",',embedded)
ck('Android embedded model still byte identical',base64.b64decode(''.join(chunks))==(R/'assets/sera_source.json').read_bytes())
# Exact v84 preservation audit: only explicitly permitted old files may change.
if BASE.is_file():
 with zipfile.ZipFile(BASE) as z:
  original={n.split('/',1)[1]:z.read(n) for n in z.namelist() if '/' in n and not n.endswith('/')}
 expected={'scripts/sword_trail.gd','project.godot','DEVELOPMENT.md'}
 changed={n for n,v in original.items() if (R/n).is_file() and (R/n).read_bytes()!=v}
 missing={n for n in original if not (R/n).exists()}
 ck('no files removed from v84',not missing)
 ck('only intended original files changed',changed==expected)
 new={p.relative_to(R).as_posix() for p in R.rglob('*') if p.is_file()}-set(original)
 ck('only authorized files added',new=={'README_v85_ja.md','tools/v85_sword_fx_self_check.py','blockbench/SERA_melee_combo_3_v85.bbmodel'})
 ck('v84 authored source JSON identical',original['assets/sera_source.json']==(R/'assets/sera_source.json').read_bytes())
 ck('camera, enemy AI, UI, step code unchanged',all((R/n).read_bytes()==v for n,v in original.items() if n.startswith('scripts/') and n!='scripts/sword_trail.gd'))
 print('v84 unchanged originals:',len(original)-len(changed))
print(f'v85 PASS: {checks} static checks')
