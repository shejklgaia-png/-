#!/usr/bin/env python3
"""Static, model-integrity and deterministic timing checks for v99."""
from pathlib import Path
import json,zipfile,base64,re,hashlib,math,sys,collections
ROOT=Path(__file__).resolve().parents[1]
OLD=Path('/mnt/data/sera_portrait_godot_melee_v98_air_step_melee_steering.zip')
USER=Path('/mnt/data/SERA_jump_stranding.bbmodel')
PKG=Path('/mnt/data/sera_portrait_godot_melee_v99_landing_hold_06s.zip')
checks=[]
def check(name,cond):
 checks.append((name,bool(cond)))
 if not cond:print('FAIL',name)
main=(ROOT/'scripts/main.gd').read_text();rig=(ROOT/'scripts/sera_rig.gd').read_text()
new=json.loads((ROOT/'assets/sera_source.json').read_text());uploaded=json.loads(USER.read_text())
with zipfile.ZipFile(OLD) as z:
 oldfiles={n.split('/',1)[1]:z.read(n) for n in z.namelist() if '/' in n and not n.endswith('/')}
old=json.loads(oldfiles['assets/sera_source.json'])
old_map={a['uuid']:a for a in old['animations']}
new_map={a['uuid']:a for a in new['animations']}
user_jump=next(a for a in uploaded['animations'] if abs(float(a.get('length',0))-0.5)<1e-10 and a.get('name','')=='')
old_jump=next(a for a in old['animations'] if a.get('name')=='Jump')
new_jump=next(a for a in new['animations'] if a.get('name')=='Jump')
check('model equal except animations',all(new[k]==old[k] for k in old if k!='animations'))
check('animation count unchanged',len(new['animations'])==len(old['animations'])==13)
check('every non-Jump animation byte-equivalent data',all(a==old_map[uid] for uid,a in new_map.items() if uid!=old_jump['uuid']))
check('same Jump uuid',old_jump['uuid']==new_jump['uuid']==user_jump['uuid'])
check('user Jump keyframes imported exactly',new_jump['animators']==user_jump['animators'])
check('source Jump duration 0.5 sec',abs(float(new_jump['length'])-.5)<1e-9)
check('old Jump duration 0.375 sec',abs(float(old_jump['length'])-.375)<1e-9)
check('new last landing time 0.500 sec',abs(max(f['time'] for ani in new_jump['animators'].values() for f in ani.get('keyframes',[]))-.5)<1e-8)
check('new 0.500 keyframe authored',sum(abs(f['time']-.5)<1e-8 for ani in new_jump['animators'].values() for f in ani.get('keyframes',[]))>=10)
check('unchanged mesh elements',new['elements']==old['elements'])
check('unchanged hierarchies',new['groups']==old['groups'] and new['outliner']==old['outliner'])
check('integrated blockbench matches source',json.loads((ROOT/'blockbench/SERA_v99_jump_landing_integrated.bbmodel').read_text())==new)
check('raw uploaded model byte preserved',USER.read_bytes()==(ROOT/'blockbench/SERA_jump_landing_user_input.bbmodel').read_bytes())
encoded=re.findall(r'^    "([A-Za-z0-9+/=]+)",$',(ROOT/'assets/sera_data.gd').read_text(),re.M)
check('Android embedded json decodes identically',base64.b64decode(''.join(encoded))==(ROOT/'assets/sera_source.json').read_bytes())
check('jump still 1.5m', 'const JUMP_HEIGHT: float = 1.50' in main)
check('80% horizontal carry retained','const JUMP_TAKEOFF_HORIZONTAL_FACTOR: float = 0.80' in main)
check('30% air steer retained','const JUMP_AIR_STEER_SPEED_FACTOR: float = 0.30' in main)
check('up flick 50 px retained','const JUMP_FLICK_MIN_VERTICAL: float = 50.0' in main)
check('original fall start retained','const JUMP_FALL_CLIP_START: float = 0.20833 / 0.375' in main)
check('0.6s hold','const JUMP_LANDING_HOLD_SECONDS: float = 0.60' in main)
check('landing transition duration','const JUMP_LANDING_MOTION_SECONDS: float = 0.125' in main)
check('air clip range end 0.375','const JUMP_AIR_CLIP_END: float = 0.375' in rig)
check('landing range end 0.5','const JUMP_LANDING_CLIP_END: float = 0.500' in rig)
check('flight progress maps to original 0.375 endpoint','clip_time = JUMP_AIR_CLIP_END * clampf(progress, 0.0, 1.0)' in rig)
check('final landing pose is held','clip_time = lerpf(JUMP_AIR_CLIP_END, JUMP_LANDING_CLIP_END, clampf(progress, 0.0, 1.0))' in rig)
check('rig never auto advances Jump while held','not (jump_playback and current_clip == JUMP_CLIP)' in rig)
check('flight transitions to landing', 'if not damage_reaction_active and rig != null:\n            _begin_landing()' in main)
check('landing motion and hold timer','landing_elapsed >= JUMP_LANDING_MOTION_SECONDS + JUMP_LANDING_HOLD_SECONDS' in main)
check('standing uses finish_jump only after timer','rig.call("finish_jump", gesture_active and direction_input.length_squared() > 0.000001, false)' in main)
check('landing lock during boost','damage_reaction_active or jump_active or landing_active' in main)
check('landing suppresses interrupted flick','gesture_suppressed_from_damage or gesture_suppressed_from_landing' in main)
check('landing intercepts release','damage_reaction_active or landing_active or suppress_release_action' in main)
check('landing guard jump','if jump_active or landing_active or damage_reaction_active or step_active' in main)
check('landing guard attack','if damage_reaction_active or landing_active or step_active' in main)
check('landing guard backward','if damage_reaction_active or landing_active or rig == null' in main)
check('landing guard sideways','if damage_reaction_active or landing_active or side == 0' in main)
check('landing frame prevents ground move','elif jumping_this_frame or landing_this_frame' in main)
check('damage interrupts landing','if landing_active:\n        # Real damage interrupts landing recovery.' in main)
check('post aerial action continues falling','_enter_jump_fall()' in main and 'resume_jump_fall()' in rig)
check('v99 version tag','SERA v99 | Jump landing recovery' in (ROOT/'project.godot').read_text())
# Test 60fps and 30fps, contact and return timing, frame granularity tolerance.
for fps in (30,60,120):
 dt=1/fps; elapsed=0.; land_transition=False;land_hold=False
 for frame in range(int(fps*1.2)):
  elapsed+=dt
  p=min(elapsed/.8,1.0)
  y=1.5*4*p*(1-p)
  if 0<p<1:check(f'positive Y in flight frame {fps}-{frame}',y>=0)
  if p>=1:break
 check(f'flight duration at {fps} fps',.8<=elapsed<.8+dt+.00001)
 landed=0.0
 while landed<0.125+0.6:
  landed+=dt
 check(f'landing lock >=0.725 s at {fps} fps',landed>=.725-1e-9 and landed<.725+dt+1e-8)
 check(f'landing pos never exceeds final key at {fps}',min(landed/.125,1.0)<=1)
# Compare existing user-facing assets and code except intended changes.
intended={'scripts/main.gd','scripts/sera_rig.gd','assets/sera_source.json','assets/sera_data.gd','project.godot','DEVELOPMENT.md'}
for name,data in oldfiles.items():
 if name not in intended:
  p=ROOT/name
  check(f'unchanged v98 file: {name}',p.is_file() and p.read_bytes()==data)
with zipfile.ZipFile(PKG) as z:
 check('ZIP CRC integrity',z.testzip() is None)
 check('ZIP entries all within version folder',all(n.startswith('sera_portrait_godot_melee_v99_landing_hold_06s/') for n in z.namelist()))
 for n in z.namelist():
  if n.endswith('/'):continue
  rel=n.split('/',1)[1]
  check(f'ZIP bytes equal disk: {rel}',z.read(n)==(ROOT/rel).read_bytes())
print('v99 tests:',sum(v for _,v in checks),'/',len(checks),'PASS')
if not all(v for _,v in checks):sys.exit(1)
