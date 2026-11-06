#!/usr/bin/env python3
"""v74 speed & project integrity checks. No Godot engine runtime involved."""
from pathlib import Path
import re,math,zipfile,hashlib,sys
root=Path(__file__).resolve().parents[1]
main=(root/'scripts/main.gd').read_text('utf8')
proj=(root/'project.godot').read_text('utf8')
checks=[]
def check(name,value):
    checks.append((name,bool(value)))
    print(('PASS ' if value else 'FAIL ')+name)
def const(name):
    m=re.search(r'^const '+re.escape(name)+r': float = ([0-9.]+)',main,re.M)
    if not m:raise AssertionError('missing float constant: '+name)
    return float(m.group(1))
close=const('STEP_CLOSE_SPEED')
far=const('STEP_SPEED')
start=const('STEP_FALLOFF_START_SURFACE_DISTANCE')
end=const('STEP_CLOSE_SURFACE_DISTANCE')
min_arc=const('STEP_MIN_ARC_LENGTH')
max_arc=const('STEP_MAX_ARC_LENGTH')
max_time=const('STEP_MAX_DURATION')
check('minimum 8.0m/s',close==8.0)
check('maximum 10.0m/s',far==10.0)
check('distance boundaries unchanged',end==2.0 and start==5.0)
check('distance-based smoothstep logic retained', all(x in main for x in (
    'var surface_distance: float = _distance_to_cube_surface(pos)',
    'var eased: float = falloff * falloff * (3.0 - 2.0 * falloff)',
    'return lerpf(STEP_SPEED, STEP_CLOSE_SPEED, eased)')))
check('step snapshot at start retained','step_speed_current = _step_speed_for_player_position(player.position)' in main)
check('step duration uses fixed step speed', 'step_duration_current = path_length / step_speed_current' in main)
check('step limits unchanged',min_arc==2.0 and max_arc==4.0 and max_time==0.40)
def speed(d):
    t=max(0.0,min(1.0,(start-d)/(start-end)))
    e=t*t*(3-2*t)
    return far+(close-far)*e
for d,exp in ((0,8),(2,8),(2.75,8.3125),(3.5,9),(4.25,9.6875),(5,10),(10,10)):
    check(f'surface distance {d:.2f}m -> {exp:.4f}m/s', math.isclose(speed(d),exp,rel_tol=1e-9))
check('speed is monotone over 2-5m',all(speed(a/10)<=speed((a+1)/10)+1e-12 for a in range(20,50)))
check('minimum 2m step lasts .25s',math.isclose(min_arc/close,0.25))
check('maximum path 4m at 10m/s fits max .4s',math.isclose(max_arc/far,max_time))
check('HUD uses computed step speed','display_speed = _step_speed_for_player_position(player.position)' in main and 'step_status_label.text = "STEP SPEED %.1fm/s" % display_speed' in main)
check('project display version', 'config/name="SERA v74 | Step Min 8mps"' in proj)
base_path=root.parent.parent/'sera_portrait_godot_melee_v73_outside_circle_boost.zip'
if base_path.is_file():
    with zipfile.ZipFile(base_path) as z:
        base={n.split('/',1)[1]:z.read(n) for n in z.namelist() if '/' in n and not n.endswith('/')}
    curr={p.relative_to(root).as_posix():p.read_bytes() for p in root.rglob('*') if p.is_file()}
    changed={n for n in base.keys()&curr.keys() if base[n]!=curr[n]}
    removed=set(base)-set(curr)
    added=set(curr)-set(base)
    check('v73 files not removed',not removed)
    check('existing file changes only main, title and development log', changed=={'scripts/main.gd','project.godot','DEVELOPMENT.md'})
    check('only v74 README and test added',added=={'README_v74_ja.md','tools/v74_step_min_speed_self_check.py'})
    base_main=base['scripts/main.gd'].decode('utf8')
    # Only intended constant / version-specific comments may differ in executable code.
    def strip_comment_lines(s):
        return '\n'.join(code for line in s.splitlines() if (code := line.split('#',1)[0].strip()))
    old_code=strip_comment_lines(base_main).replace('const STEP_CLOSE_SPEED: float = 6.0','const STEP_CLOSE_SPEED: float = 8.0')
    new_code=strip_comment_lines(main)
    check('no other executable code changed',old_code==new_code)
else:
    print('INFO: v73 zip not found; differential test skipped')
print(f'{sum(ok for _,ok in checks)}/{len(checks)} checks passed')
sys.exit(0 if all(ok for _,ok in checks) else 1)
