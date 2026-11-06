#!/usr/bin/env python3
"""v70 static regression check. Does not run Godot or Android."""
from pathlib import Path
import json,base64,re,zipfile,math
root=Path(__file__).resolve().parents[1]
zip_path=root.parents[1]/'sera_portrait_godot_melee_v69_damage_knockback.zip'
checks=[]
def check(name,passed):
    checks.append((name,bool(passed)))
    print(('PASS' if passed else 'FAIL')+' '+name)
current={p.relative_to(root).as_posix():p.read_bytes() for p in root.rglob('*') if p.is_file()}
source=json.loads(current['assets/sera_source.json'].decode('utf8'))
clips=source['animations']
clip=clips[-1]
check('Damageknock only, 8 motions', len(clips)==8 and clip['name']=='Damageknock' and clip['loop']=='once')
check('new motion duration exactly 0.22s',abs(clip['length']-0.22)<1e-8)
check('key times inside duration',all(-1e-7<=k['time']<=0.220001 for a in clip['animators'].values() for k in a.get('keyframes',[])))
check('final key at clip end',any(abs(k['time']-0.22)<1e-5 for a in clip['animators'].values() for k in a.get('keyframes',[])))
embed=current['assets/sera_data.gd'].decode('utf8')
parts=re.findall(r'^\s*"([A-Za-z0-9+/=]+)",$',embed,re.M)
check('Android fallback bytes exactly match JSON',base64.b64decode(''.join(parts))==current['assets/sera_source.json'])
main=current['scripts/main.gd'].decode('utf8')
check('range 1.20m', 'const DAMAGE_KNOCKBACK_DISTANCE: float = 1.20' in main)
check('duration unchanged at 0.24s', 'const DAMAGE_KNOCKBACK_DURATION: float = 0.24' in main)
check('collision-aware displacement retained', '_move_player_swept(damage_knockback_direction * (DAMAGE_KNOCKBACK_DISTANCE * (new_eased - old_eased)), true)' in main)
check('motion and displacement both finish before unlock', 'damage_knockback_elapsed >= DAMAGE_KNOCKBACK_DURATION and rig != null and bool(rig.call("damage_finished"))' in main)
check('renamed title', 'SERA v70 | Damage Knockback 1.2m' in current['project.godot'].decode('utf8'))
check('shooter still 2s', 'var fire_interval_min: float = 2.0' in current['scripts/enemy_shooter.gd'].decode('utf8') and 'var fire_interval_max: float = 2.0' in current['scripts/enemy_shooter.gd'].decode('utf8'))
check('projectile still 12m/s', 'var projectile_speed: float = 12.0' in current['scripts/enemy_shooter.gd'].decode('utf8') and 'var travel_speed: float = 12.0' in current['scripts/enemy_projectile.gd'].decode('utf8'))
bbs=[]
for k,v in current.items():
    if k.startswith('blockbench/') and k.endswith('.bbmodel'):
        b=json.loads(v.decode('utf8'))
        if len(b.get('animations',[]))==8:
            bbs.append(k)
            check('retimed editable Blockbench '+k,b['animations']==clips and b['elements']==source['elements'] and b['outliner']==source['outliner'])
check('three editable models retimed',len(bbs)==3)
if zip_path.exists():
    with zipfile.ZipFile(zip_path) as z:
        orig={n.split('/',1)[1]:z.read(n) for n in z.namelist() if '/' in n and not n.endswith('/')}
    changed={k for k in orig.keys()&current.keys() if orig[k]!=current[k]}
    expected={'assets/sera_source.json','assets/sera_data.gd','scripts/main.gd','project.godot','DEVELOPMENT.md','tools/v68_damage_self_check.py'}|set(bbs)
    check('all v69 files retained', not(set(orig)-set(current)))
    check('only intended previous files modified',changed==expected)
    old=json.loads(orig['assets/sera_source.json'])
    check('seven existing clips identical',clips[:7]==old['animations'][:7])
    check('geometry, bones, model structures identical', all(source[k]==old[k] for k in source if k!='animations') and set(source)==set(old))
    oldclip=old['animations'][-1]
    ratio=0.22/oldclip['length']
    temp=json.loads(json.dumps(oldclip))
    temp['length']=0.22
    for a in temp['animators'].values():
        for k in a.get('keyframes',[]):k['time']=round(float(k['time'])*ratio,6)
    check('Damageknock keyframes retimed only',temp==clip)
else:
    print('INFO: v69 ZIP absent, base diff checks skipped')
count=sum(x for n,x in checks)
print(f'\n{count}/{len(checks)} v70 static checks passed')
if count!=len(checks):raise SystemExit(1)
