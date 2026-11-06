#!/usr/bin/env python3
"""Portable v68 static self-test. Does not execute Godot or require v67 files."""
from pathlib import Path
import base64
import json
import re

root=Path(__file__).resolve().parents[1]
checks=[]
def check(name, valid):
    checks.append((name, bool(valid)))
    print(('PASS' if valid else 'FAIL') + ': ' + name)

raw=(root/'assets/sera_source.json').read_bytes()
model=json.loads(raw)
clips={a['name']:a for a in model['animations']}
damage_name='Damageknock' if 'Damageknock' in clips else 'Damage_motion'
required={'Wait_motion','Wait_Pose','meleeboost','run_front_original','melee1','Step_R','Step_L',damage_name}
check('eight expected clips',set(clips)==required)
check('non-looping authored damage',clips[damage_name]['loop']=='once' and clips[damage_name]['length'] in (0.5,0.16667,0.22))
bones={a['uuid'] for a in model['groups']}
check('bone count is unchanged',len(bones)==22)
check('element count is unchanged',len(model['elements'])==25)
check('damage uses existing bone identifiers',set(clips[damage_name]['animators']).issubset(bones))
check('damage keyframes remain in time window',all(0<=key['time']<=clips[damage_name]['length'] for anim in clips[damage_name]['animators'].values() for key in anim.get('keyframes',[])))
emb=(root/'assets/sera_data.gd').read_text('utf8')
parts=re.findall(r'^    "([A-Za-z0-9+/=]+)",$',emb,re.M)
check('embedded Android model equals JSON asset',base64.b64decode(''.join(parts))==raw)
bb=json.loads((root/'blockbench/セラ_被弾モーション統合.bbmodel').read_text('utf8'))
check('editable Blockbench model matches in-game model',bb==model)
main=(root/'scripts/main.gd').read_text('utf8')
rig=(root/'scripts/sera_rig.gd').read_text('utf8')
check('enemy projectile hit triggers reaction','_begin_damage_reaction(incoming_direction)' in main or '_begin_damage_reaction()' in main)
check('interrupted gestures cannot queue actions','if damage_reaction_active or suppress_release_action:' in main)
check('player inputs blocked during reaction', 'if damage_reaction_active or step_active' in main and 'if damage_reaction_active or side == 0' in main)
check('clip completion returns to locomotion','damage_finished' in main and 'finish_damage' in main)
check('animation lock for movement','combat_playback or step_playback or damage_playback' in rig)
check('original enemy firing speed stays 12m/s','var projectile_speed: float = 12.0' in (root/'scripts/enemy_shooter.gd').read_text('utf8'))
check('original 2s firing cycle stays','var fire_interval_min: float = 2.0' in (root/'scripts/enemy_shooter.gd').read_text('utf8'))
missing=[]
for script in root.rglob('*.gd'):
    for resource in re.findall(r'(?:preload|load)\("res://([^"\)]+)"\)', script.read_text('utf8')):
        if not (root/resource).exists(): missing.append(resource)
check('script resource references exist',not missing)
print(f'{sum(v for _,v in checks)}/{len(checks)} static checks passed')
if not all(v for _,v in checks):
    raise SystemExit(1)
