#!/usr/bin/env python3
"""v101 guard regression, asset integrity and input state-contract checks."""
from pathlib import Path
import json, re, base64, zipfile, hashlib
ROOT=Path(__file__).resolve().parents[1]
ORIGINAL=Path('/mnt/data/sera_portrait_godot_melee_v100_jump_debug_only.zip')
INPUT=Path('/mnt/data/SERA_Guard.bbmodel')
checks=[]
def test(name, ok):
    checks.append((name,bool(ok)))
    if not ok: print('FAIL:',name)
main=(ROOT/'scripts/main.gd').read_text('utf-8')
rig=(ROOT/'scripts/sera_rig.gd').read_text('utf-8')
source=json.loads((ROOT/'assets/sera_source.json').read_text('utf-8'))
model=json.loads((ROOT/'blockbench/SERA_v101_guard_integrated.bbmodel').read_text('utf-8'))
user=json.loads(INPUT.read_text('utf-8'))
guard=next(x for x in user['animations'] if x['name']=='Guard')
test('source equals integrated Blockbench model',source==model)
test('source has exactly one Guard clip',sum(x['name']=='Guard' for x in source['animations'])==1)
test('guard original keyframes preserved',source['animations'][-1]==guard)
test('guard keys compatible with all existing bones',set(guard['animators'])=={x['uuid'] for x in source['groups']})
test('guard stationary authored single pose',guard.get('length')==0 and all(k['time']==0 for a in guard['animators'].values() for k in a.get('keyframes',[])))
parts=re.findall(r'^\s+"([A-Za-z0-9+/=]+)",?$',(ROOT/'assets/sera_data.gd').read_text('utf-8'),re.M)
test('embedded data identical to source',base64.b64decode(''.join(parts))==(ROOT/'assets/sera_source.json').read_bytes())
test('guard rig loaded', 'animations.has(GUARD_CLIP)' in rig and 'const GUARD_CLIP: String = "Guard"' in rig)
test('guard uses pose clip and release blend', 'func start_guard()' in rig and '_switch_clip(GUARD_CLIP, 0.095)' in rig and 'func finish_guard()' in rig and '_switch_clip(WAIT_CLIP, 0.11)' in rig)
test('guard prevents rig movement', 'or guard_playback:' in rig)
test('guard starts on stationary hold', 'gesture_max_travel <= TAP_MAX_TRAVEL' in main and '>= GUARD_HOLD_SECONDS' in main and 'func _update_guard_hold()' in main)
test('hold threshold and tap duration agree', 'const GUARD_HOLD_SECONDS: float = TAP_MAX_DURATION' in main)
test('guard tracks whether screen touch is active', 'if not keyboard_guard_held and not gesture_active:' in main)
test('guard freezes motion input', 'guard_active = true\n        direction_input = Vector2.ZERO\n        player.velocity = Vector3.ZERO' in main)
test('guard prevents move/boost', 'if not gesture_active or guard_active or damage_reaction_active' in main)
test('guard prevents drag while held', 'if not gesture_active or guard_active:' in main)
test('guard release consumes gesture', 'if guard_active:\n        # Consume the whole hold' in main)
for name in ('_start_attack','_start_side_step','_start_back_step'):
    tail=main.split('func '+name+'(',1)[1].split('func ',1)[0]
    test(name+' blocked under guard','if guard_active or ' in tail)
test('jump debug blocked under guard', 'if guard_active or jump_active or landing_active' in main)
test('guard does not permit start during another action', 'not jump_active and not step_active and combat_state == CombatState.IDLE' in main)
test('enemy hit has blocked guard path', 'if guard_active:\n        # A guarded hit' in main)
test('damage reaction defensive suppression', 'if guard_active or damage_reaction_active or rig == null' in main)
test('guard evaluated per physics frame','func _physics_process(delta: float) -> void:\n    _update_guard_hold()' in main)
test('debug G key hold supported', 'event.keycode == KEY_G' in main and 'keyboard_guard_held = event.pressed' in main)
test('guard status label', 'state_label.text = "GUARD  |  Guard"' in main)
test('jump remains debug only', 'const JUMP_TOUCH_INPUT_ENABLED: bool = false' in main)
test('melee 3 hits unchanged', 'const STRIKE_DAMAGE = [12, 12, 26]' in main)
test('backstep remains 4m', 'const BACK_STEP_DISTANCE: float = 4.0' in main)
test('base renderer unchanged','renderer/rendering_method="gl_compatibility"' in (ROOT/'project.godot').read_text('utf-8'))
if ORIGINAL.exists():
 with zipfile.ZipFile(ORIGINAL) as archive:
    originals={n.split('/',1)[1]:archive.read(n) for n in archive.namelist() if '/' in n and not n.endswith('/')}
    allow={'assets/sera_source.json','assets/sera_data.gd','scripts/main.gd','scripts/sera_rig.gd','project.godot','DEVELOPMENT.md'}
    for p,old in originals.items():
        actual=(ROOT/p)
        test('original preserved: '+p,actual.is_file() and (p in allow or actual.read_bytes()==old))
    old_json=json.loads(originals['assets/sera_source.json'])
    test('existing model+animations unchanged', source['animations'][:-1]==old_json['animations'] and all(source[k]==old_json[k] for k in source if k!='animations'))
    test('only approved originals changed', {p for p in originals if (ROOT/p).read_bytes()!=originals[p]}==allow)
print('v101 guard: %d/%d passed' %(sum(ok for _,ok in checks),len(checks)))
if not all(ok for _,ok in checks):raise SystemExit(1)
