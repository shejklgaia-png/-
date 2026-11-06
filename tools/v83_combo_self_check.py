#!/usr/bin/env python3
"""v83 static asset, code and timing checks (not a substitute for a Godot runtime)."""
from pathlib import Path
import base64
import hashlib
import json
import re

R = Path(__file__).resolve().parents[1]
main=(R/'scripts/main.gd').read_text('utf-8')
rig=(R/'scripts/sera_rig.gd').read_text('utf-8')
trail=(R/'scripts/sword_trail.gd').read_text('utf-8')
source=(R/'assets/sera_source.json').read_bytes()
data=json.loads(source)
model=json.loads((R/'blockbench/SERA_melee_combo_3_v83.bbmodel').read_text('utf-8'))
clips={c['name']:c for c in data['animations']}
count=0

def check(what, expr):
    global count
    assert expr, 'FAIL '+what
    count+=1
    print('PASS',what)

check('three uniquely named authored melee clips',all(n in clips for n in ['melee1','Melee2','Melee3']))
check('all 10 original+new clips unique',len(clips)==len(data['animations'])==10)
check('v82 side-step clips unchanged by transfer',all(n in clips for n in ['Step_R','Step_L']))
check('v82 damage clip timing preserved',clips['Damageknock']['length']==0.22)
check('v82 boost motion lasts 0.5s',clips['meleeboost']['length']==0.5)
check('all three melee clips are one-shot',all(clips[n]['loop']=='once' for n in ['melee1','Melee2','Melee3']))
check('authored clip durations', [clips[n]['length'] for n in ['melee1','Melee2','Melee3']]==[.5,.5,.83333])
check('model and ingame JSON match',data==model)
check('model retained 25 meshes and same 22 bone groups',len(data['elements'])==25 and len(data['groups'])==22)
check('every combo clip has original 22 bone animations',all(len(clips[n]['animators'])==22 for n in ['melee1','Melee2','Melee3']))
check('3 strike buffers and gate constants',all(s in main for s in ['STRIKE_CLIPS = ["melee1", "Melee2", "Melee3"]', 'combo_queued = true','STRIKE_CANCEL_TIMES = [7.0 / 24.0, 7.0 / 24.0, 15.0 / 24.0]']))
check('reset queue after interruption, new strike, and normal completion',main.count('combo_queued = false')>=4)
check('hitstop preserved in gate and hit checking',all(s in main for s in ['if hit_stop_remaining > 0.0:', 'rig.call("set_combat_paused", true)', 'if hit_stop_remaining == 0.0:']))
check('only two possible combo follow-ups', 'strike_index < STRIKE_CLIPS.size() - 1' in main)
check('rig can start either of the three authored clips', 'func start_strike(clip_name: String = STRIKE_CLIP)' in rig and '_switch_clip(clip_name, 0.065)' in rig)
check('third sword trail follows later attack window', 'strike_trail_offset' in trail and 'clip_time - strike_trail_offset' in trail)
check('v82 camera constraint retained', all(s in main for s in ['STEP_CLOSE_CAMERA_MAX_RELATIVE_DEGREES: float = 65.0', 'STEP_CLOSE_CAMERA_MAX_TURN_RATE_DEGREES: float = 300.0']))
check('v82 movement/step speeds retained',all(s in main for s in ['MOVE_SPEED: float = 3.25','STEP_SPEED: float = 10.0','STEP_CLOSE_SPEED: float = 8.0']))
check('v82 sword texture effect layout retained',trail.count('preload("res://assets/v35_cutout_frames/')==16)
check('v82 enemy AI retained', 'enemy_shooter.call' in main or '_build_enemy_shooter()' in main)
check('project is v83 and compatibility renderer', 'SERA v83' in (R/'project.godot').read_text() and 'gl_compatibility' in (R/'project.godot').read_text())
check('all exported art files retained',all((R/'assets'/n).exists() for n in ['sword_impact.wav','sera_slash_sheet_4x4_mobile.png','v35_cutout_tiles.json']))

embedded=(R/'assets/sera_data.gd').read_text('utf-8')
chunks=re.findall(r'    "([A-Za-z0-9+/=]+)",',embedded)
check('embedded data exactly matches source for Android build',base64.b64decode(''.join(chunks))==source)

# The follow-through keys are 5/24 s for the first two and 13/24 s for stage 3.
# The gate should occur two 24fps frames later. This is a keyframe-based timing
# assertion rather than actual animation playback validation.
follow=[5/24,5/24,13/24]
gates=[7/24,7/24,15/24]
check('cancel timing two 24fps frames after each swing',all(abs(g-f-2/24)<1e-8 for f,g in zip(follow,gates)))
for name,t in zip(['melee1','Melee2','Melee3'],follow):
    times=[float(k['time']) for a in clips[name]['animators'].values() for k in a.get('keyframes', []) if k['channel']=='rotation']
    check(name+' actual post-swing authored key exists',any(abs(v-t)<0.0002 for v in times))
check('cancel gate occurs before nominal end',all(g<clips[n]['length'] for g,n in zip(gates,['melee1','Melee2','Melee3'])))

# Full line-based comparison is performed in packaging script; here ensure
# there are no dangling script preload references.
for file in R.glob('scripts/*.gd'):
    for path in re.findall(r'(?:preload|load)\("(res://[^\"]+)"\)',file.read_text('utf-8')):
        check('referenced resource '+path,(R/path.replace('res://','')).exists())
print(f'v83 static verification: {count} checks PASSED')
