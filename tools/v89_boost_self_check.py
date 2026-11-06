#!/usr/bin/env python3
"""SERA v89 BOOST clip integration and v88 regression checks (static only)."""
from pathlib import Path
import base64
import json
import re
import hashlib

R=Path(__file__).resolve().parents[1]
source=(R/'assets/sera_source.json').read_bytes()
model=json.loads(source)
user_bytes=(R/'blockbench/SERA_boost_front_user_input.bbmodel').read_bytes()
user=json.loads(user_bytes)
integrated=json.loads((R/'blockbench/SERA_v89_boost_integrated.bbmodel').read_bytes())
rig=(R/'scripts/sera_rig.gd').read_text()
main=(R/'scripts/main.gd').read_text()
project=(R/'project.godot').read_text()
readme=(R/'README_v89_ja.md').read_text()
checks=0

def check(label,actual):
    global checks
    assert actual, label
    checks+=1
    print('PASS',label)

check('v89 project name', 'SERA v89' in project)
check('Godot GL compatibility preserved', 'gl_compatibility' in project)
check('authored file preserved as valid JSON .bbmodel', user['meta']['model_format']=='free')
check('Boost_front in original user file', sum(a['name']=='Boost_front' for a in user['animations'])==1)
check('new runtime JSON and integrated edit source identical', integrated==model)
check('v89 has exactly 12 unique animations', len(model['animations'])==len(set(a['name'] for a in model['animations']))==12)
check('Boost_front is the only new last clip', model['animations'][-1]['name']=='Boost_front')
authored=next(a for a in user['animations'] if a['name']=='Boost_front')
boost=model['animations'][-1]
check('Boost_front imported without editing keyframes or settings', boost==authored)
check('original single-pose zero-length loop preserved', boost['loop']=='loop' and boost['length']==0)
keyframes=[f for a in boost['animators'].values() for f in a.get('keyframes',[])]
check('21 pose keyframes all at time zero', len(keyframes)==21 and all(float(f['time'])==0 for f in keyframes))
check('bone tracks exist in original 22-bone hierarchy', set(boost['animators']).issubset({a['uuid'] for a in model['groups']}))
check('original element geometry retained', model['elements']==user['elements'])
check('original outliner retained', model['outliner']==user['outliner'])
check('original user textures retained', model['textures']==user['textures'])
check('readme documents intent', 'Boost_front' in readme and '単一ポーズ' in readme)
check('new clip source name present in rig', 'const BOOST_CLIP: String = "Boost_front"' in rig)
check('boost required to load rig', 'animations.has(BOOST_CLIP)' in rig)
check('set_moving distinguishes moving and boosting', 'func set_moving(moving: bool, boosting: bool = false)' in rig)
check('moving boost chooses new clip and run chooses old clip', 'wanted = BOOST_CLIP if boosting else RUN_CLIP' in rig)
check('no boost otherwise when standing still', 'var wanted: String = WAIT_CLIP\n    if moving:' in rig)
check('animation blends between postures with existing blend', '_switch_clip(wanted, BLEND_SECONDS)' in rig and 'const BLEND_SECONDS: float = 0.16' in rig)
check('main sends requested boost state each physics frame', 'rig.call("set_moving", running, movement_boost_active)' in main)
check('no double set_moving call', main.count('rig.call("set_moving",')==1)
check('boost HUD shows new pose', 'BOOST  x1.5  |  Boost_front' in main)
check('boost speed unchanged', 'const MOVEMENT_BOOST_MULTIPLIER: float = 1.5' in main)
check('boost selected only outside drag radius', 'var boost_requested: bool = (pos.distance_squared_to(pointer_origin)' in main and ' > DRAG_RADIUS * DRAG_RADIUS' in main)
check('back step still 4m', 'const BACK_STEP_DISTANCE: float = 4.0' in main)
check('back step still authored pose', 'const STEP_BACK_CLIP: String = "Backstep"' in rig and '_switch_clip(STEP_BACK_CLIP, 0.055)' in rig)
check('side steps still use authored clips', all(x in rig for x in ['const STEP_LEFT_CLIP: String = "Step_L"','const STEP_RIGHT_CLIP: String = "Step_R"']))
check('three-strike damage values 12+12+26', 'const STRIKE_DAMAGE = [12, 12, 26]' in main)
check('distinct melee approach animation unchanged', 'const MELEE_APPROACH_CLIP: String = "meleeboost"' in rig and '_switch_clip(MELEE_APPROACH_CLIP, 0.045)' in rig)
check('afterimage step boost data preserved', 'AFTERIMAGE_BOOST_LIFETIME: float = 0.14' in rig and 'AFTERIMAGE_STEP_LIFETIME: float = 0.22' in rig)
check('clip processing handles authored zero length', 'maxf(float(clip.get("length", 1.0)), 0.001)' in rig and 'fposmod(clip_time, clip_length)' in rig)
chunks=re.findall(r'^    "([A-Za-z0-9+/=]+)",$',(R/'assets/sera_data.gd').read_text(),flags=re.M)
check('embedded model base64 exactly matches JSON',base64.b64decode(''.join(chunks))==source)
for fn in ('assets/sera_godot_shading_texture.png','scenes/main.tscn','scripts/enemy_shooter.gd','scripts/enemy_projectile.gd','scripts/touch_overlay.gd'):
    check('core file preserved '+fn,(R/fn).exists())
for filepath in (R/'scripts').glob('*.gd'):
    for dep in re.findall(r'(?:preload|load)\("(res://[^\"]+)"\)',filepath.read_text()):
        check('resource exists '+dep,(R/dep[6:]).exists())
print(f'v89 static tests: {checks} passed; runtime not tested')
