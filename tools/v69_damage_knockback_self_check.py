#!/usr/bin/env python3
"""v69 compatibility/static checks. Does not execute the Godot engine."""
from pathlib import Path
import base64, hashlib, json, math, re, zipfile

root=Path(__file__).resolve().parents[1]
base=Path('/mnt/data')
checks=[]

def check(label, condition):
    condition=bool(condition)
    checks.append((label,condition))
    print(('PASS' if condition else 'FAIL')+': '+label)

master=json.loads((root/'assets/sera_source.json').read_text('utf8'))
clips=master['animations']
check('8 motions; original seven preserved names', [a['name'] for a in clips]==['Wait_motion','Wait_Pose','meleeboost','run_front_original','melee1','Step_R','Step_L','Damageknock'])
newclip=clips[-1]
check('new Blockbench clip is exact duration and nonlooping',newclip['loop']=='once' and newclip['length']==0.16667)
check('damage keyframes within clip',all(0.0<=k['time']<=newclip['length'] for v in newclip['animators'].values() for k in v.get('keyframes',[])))
check('authoritative model has 22 bones and 25 elements',len(master['groups'])==22 and len(master['elements'])==25)
check('all damage animators use existing group IDs', set(newclip['animators']).issubset({g['uuid'] for g in master['groups']}))
check('integrated editor model matches', json.loads((root/'blockbench/セラ_ダメージノックバック統合.bbmodel').read_text('utf8'))==master)
check('v68 editor model updated', json.loads((root/'blockbench/セラ_被弾モーション統合.bbmodel').read_text('utf8'))==master)
check('embedded APK resource matches exactly',base64.b64decode(''.join(re.findall(r'^    "([A-Za-z0-9+/=]+)",$',(root/'assets/sera_data.gd').read_text('utf8'),re.M)))==(root/'assets/sera_source.json').read_bytes())

main=(root/'scripts/main.gd').read_text('utf8')
rig=(root/'scripts/sera_rig.gd').read_text('utf8')
proj=(root/'scripts/enemy_projectile.gd').read_text('utf8')
shooter=(root/'scripts/enemy_shooter.gd').read_text('utf8')
check('rig uses new short Blockbench clip','const DAMAGE_CLIP: String = "Damageknock"' in rig and '_switch_clip(DAMAGE_CLIP, 0.025)' in rig)
check('projectile hit signal includes its travel direction','signal player_hit(world_position: Vector3, travel_direction: Vector3)' in proj and 'player_hit.emit(hit_position, travel_direction)' in proj)
check('shooter transparently relays impact direction','signal projectile_hit(world_position: Vector3, travel_direction: Vector3)' in shooter and 'projectile_hit.emit(world_position, travel_direction)' in shooter)
check('main impact callback receives direction','func _on_enemy_projectile_hit(_world_position: Vector3, incoming_direction: Vector3)' in main and '_begin_damage_reaction(incoming_direction)' in main)
check('knockback uses horizontal bullet vector','Vector3(incoming_direction.x, 0.0, incoming_direction.z)' in main and 'damage_knockback_direction = horizontal_push.normalized()' in main)
check('knockback moves through swept body collision','_move_player_swept(damage_knockback_direction * (DAMAGE_KNOCKBACK_DISTANCE * (new_eased - old_eased)), true)' in main)
check('knockback distance and duration', 'DAMAGE_KNOCKBACK_DISTANCE: float = 0.80' in main and 'DAMAGE_KNOCKBACK_DURATION: float = 0.24' in main)
check('damage exit requires both animation and motion','damage_knockback_elapsed >= DAMAGE_KNOCKBACK_DURATION and rig != null and bool(rig.call("damage_finished"))' in main)
check('input remains suppressed and blocked','if damage_reaction_active or suppress_release_action:' in main and 'if damage_reaction_active or step_active' in main and 'if damage_reaction_active or side == 0' in main)
check('damage animation cannot restart during damage','if damage_reaction_active or rig == null' in main and 'if not loading_ok or damage_playback:' in rig)
check('animation ends to idle/motion','rig.call("finish_damage", gesture_active and direction_input.length_squared() > 0.000001)' in main)
check('projectile velocity unchanged','var projectile_speed: float = 12.0' in shooter and 'var travel_speed: float = 12.0' in proj)
check('shooting cadence unchanged', 'var fire_interval_min: float = 2.0' in shooter and 'var fire_interval_max: float = 2.0' in shooter and 'var first_shot_delay: float = 2.0' in shooter)
check('no unexpected movement code change','_advance_side_step(delta)' in main and '_advance_attack(delta)' in main and 'func _move_player_swept(motion: Vector3, slide_on_wall: bool)' in main)

# Duration/displacement independent of physics timestep; collision-free case.
def integrate(dt):
    elapsed=0.0; distance=0.0
    while elapsed<0.24-1e-10:
        p0=elapsed/0.24
        elapsed=min(0.24,elapsed+dt)
        p1=elapsed/0.24
        f=lambda t: 1.0-(1.0-t)**2
        distance+=0.80*(f(p1)-f(p0))
    return distance
check('ease-out integrates to 0.8m across frame rates',all(abs(integrate(d)-0.80)<1e-9 for d in (1/15,1/30,1/60,1/120,0.4)))
check('ease-out is forward monotonic',all((1.0-(1.0-(i+1)/20)**2) >= (1.0-(1.0-i/20)**2) for i in range(20)))

# Resource checks; reject invalid or duplicate GDScript function definitions.
missing=[];duplicate_funcs=[];bad_indent=[]
for script in root.rglob('*.gd'):
    content=script.read_text('utf8')
    for path in re.findall(r'(?:preload|load)\("res://([^"\)]+)"\)',content):
        if not (root/path).exists():missing.append((script.name,path))
    names=re.findall(r'^func ([A-Za-z_0-9]+)\(',content,re.M)
    if len(names)!=len(set(names)):duplicate_funcs.append(script.name)
    for n,line in enumerate(content.splitlines(),1):
        if line.startswith('\t'):bad_indent.append((script.name,n))
check('no missing preload resources',not missing)
check('no duplicate GDScript functions',not duplicate_funcs)
check('scripts use consistent 4-space indent',not bad_indent)

# Exact v68 comparison on disk, if present, otherwise skip without failure.
basezip=base/'sera_portrait_godot_melee_v68_damage_reaction.zip'
if basezip.exists():
    with zipfile.ZipFile(basezip) as z:
        originals={name.split('/',1)[1]:z.read(name) for name in z.namelist() if '/' in name and not name.endswith('/')}
    current={str(path.relative_to(root)):path.read_bytes() for path in root.rglob('*') if path.is_file()}
    changed={p for p in originals.keys() & current.keys() if originals[p]!=current[p]}
    missing_orig=set(originals)-set(current)
    expected_changed={'assets/sera_source.json','assets/sera_data.gd','scripts/sera_rig.gd','scripts/main.gd','scripts/enemy_projectile.gd','scripts/enemy_shooter.gd','project.godot','DEVELOPMENT.md','tools/v68_damage_self_check.py'}
    expected_changed.update(p for p in originals if p.startswith('blockbench/') and len(json.loads(originals[p].decode('utf8')).get('animations',[]))==8)
    check('v68 files retained',not missing_orig)
    check('only intended v68 files changed',changed==expected_changed)
    check('remaining original files byte-identical', all(current[p]==originals[p] for p in (set(originals)-changed)))
    o=json.loads(originals['assets/sera_source.json'].decode('utf8'))
    check('seven preexisting animations bit-for-bit unchanged',clips[:7]==o['animations'][:7])
    check('all non-animation source data unchanged',all(master[k]==o[k] for k in master if k!='animations') and set(master)==set(o))
else:
    print('INFO: original zip not present, skipped detailed diff checks')

ok=sum(1 for _,success in checks if success)
print(f'\n{ok}/{len(checks)} v69 static checks passed')
if ok!=len(checks):raise SystemExit(1)
