#!/usr/bin/env python3
"""Self-contained v102 guard clip + embedded data integrity checks."""
from pathlib import Path
import json,base64,re,hashlib
root=Path(__file__).resolve().parents[1]
checks=[]
def verify(label,result):
    checks.append((label,bool(result)))
    if not result:print('FAIL:',label)
source=(root/'assets/sera_source.json').read_bytes()
model=json.loads(source)
merged=(root/'blockbench/SERA_v102_guardfix_integrated.bbmodel').read_bytes()
original=json.loads((root/'blockbench/SERA_Guardfix_user_input.bbmodel').read_text('utf-8'))
fix=next(a for a in original['animations'] if a.get('name')=='Guard')
guards=[a for a in model['animations'] if a.get('name')=='Guard']
verify('one Guard clip',len(guards)==1)
verify('merged model matches source byte-for-byte',merged==source)
verify('input clip equals integrated clip',len(guards)==1 and guards[0]==fix)
verify('22 skeleton UUIDs matched',set(fix['animators'])=={g['uuid'] for g in model['groups']} and len(fix['animators'])==22)
verify('zero-time pose with loop',fix['length']==0 and fix['loop']=='loop' and all(k.get('time')==0 for a in fix['animators'].values() for k in a.get('keyframes',[])))
parts=re.findall(r'^\s+"([A-Za-z0-9+/=]+)",?$',(root/'assets/sera_data.gd').read_text('utf-8'),re.M)
verify('embedded data equals source',bool(parts) and base64.b64decode(''.join(parts))==source)
rig=(root/'scripts/sera_rig.gd').read_text('utf-8')
main=(root/'scripts/main.gd').read_text('utf-8')
verify('guard uses named animation', 'const GUARD_CLIP: String = "Guard"' in rig and '_switch_clip(GUARD_CLIP, 0.095)' in rig)
verify('guard input active', 'func _update_guard_hold()' in main and 'const GUARD_HOLD_SECONDS: float = TAP_MAX_DURATION' in main)
verify('guard suppresses damage reaction', 'if guard_active or damage_reaction_active or rig == null' in main)
verify('no guard movement', 'if not gesture_active or guard_active or damage_reaction_active' in main)
verify('old combat damage unchanged', 'const STRIKE_DAMAGE = [12, 12, 26]' in main)
print('v102 static check: %d/%d passed' % (sum(v for _,v in checks),len(checks)))
if not all(v for _,v in checks):raise SystemExit(1)
