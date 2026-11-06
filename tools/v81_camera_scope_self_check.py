#!/usr/bin/env python3
"""v81 scope-error and regression checks. Static checks, NOT Godot runtime."""
from pathlib import Path
from zipfile import ZipFile
import re, sys, hashlib
root=Path(__file__).resolve().parents[1]
basezip=root.parent/'sera_portrait_godot_melee_v80_close_step_camera.zip'
main=(root/'scripts/main.gd').read_text(encoding='utf-8')
project=(root/'project.godot').read_text(encoding='utf-8')
checks=[]
def ck(name, predicate):
    val=bool(predicate)
    checks.append((name,val))
    print(('PASS ' if val else 'FAIL ')+name)

def get_function_block(src, funcname):
    m=re.search(rf'^func {funcname}\([^\n]*\) -> void:\n',src,re.M)
    assert m, funcname
    following=re.search(r'^func |^static func ',src[m.end():], re.M)
    end=m.end()+following.start() if following else len(src)
    return src[m.end():end]

physics=get_function_block(main, '_physics_process')
process=get_function_block(main, '_process')
# A v80 mistake declared the flag with four-space indent in the _physics_process
# function; _process then could not access the local variable.
ck('flag is declared at script member scope',bool(re.search(r'^var close_step_camera_this_frame: bool = false$',main,re.M)))
ck('flag appears in exactly one declaration',len(re.findall(r'\bvar\s+close_step_camera_this_frame\b',main))==1)
ck('flag assigned in _physics_process, not locally declared',
    '    close_step_camera_this_frame = stepping_this_frame and step_close_camera' in physics
    and 'var close_step_camera_this_frame' not in physics)
ck('snapshot is before step update',
    physics.find('close_step_camera_this_frame = stepping_this_frame and step_close_camera')
    < physics.find('_advance_side_step(delta)'))
ck('flag used in render frame process', '    if close_step_camera_this_frame:' in process)
ck('close-camera limiter keeps +/-18 degrees', 'const STEP_CLOSE_CAMERA_MAX_ORBIT_DEGREES: float = 18.0' in main and
    'camera_yaw = step_camera_start_yaw + clampf(relative_yaw' in process)
ck('near-step threshold 1m preserved', 'const STEP_CLOSE_CAMERA_SURFACE_DISTANCE: float = 1.0' in main)
ck('screen edge correction bypass preserved', '    elif running:' in process and '        _enforce_screen_edge(bearing)' in process)
ck('normal camera settings restored', 'const CAMERA_FOLLOW_RATE: float = 1.65' in main and 'const CAMERA_MOVING_YAW_SCALE: float = 0.55' in main)
ck('no v79 fast camera path', 'CAMERA_ACTION_FOLLOW_RATE' not in main and 'CAMERA_ACTION_YAW_SCALE' not in main)
ck('run/boost speed untouched', 'const MOVE_SPEED: float = 3.25' in main and 'const MOVEMENT_BOOST_MULTIPLIER: float = 1.5' in main)
ck('step speed untouched', 'const STEP_CLOSE_SPEED: float = 8.0' in main and 'const STEP_SPEED: float = 10.0' in main)
ck('project renderer and version', 'SERA v81 | Close Step Camera Scope Fix' in project and 'renderer/rendering_method="gl_compatibility"' in project)
ck('damage knockback untouched', 'const DAMAGE_KNOCKBACK_DISTANCE: float = 1.20' in main)
ck('enemy cadence untouched', 'var fire_interval_min: float = 2.0' in (root/'scripts/enemy_shooter.gd').read_text())
ck('enemy projectile velocity untouched', 'var travel_speed: float = 12.0' in (root/'scripts/enemy_projectile.gd').read_text())
ck('temporal afterimages intact', '_update_motion_blur(delta)' in main and (root/'scripts/sera_rig.gd').is_file())
if basezip.exists():
    with ZipFile(basezip) as z:
        originals={name.split('/',1)[1]:z.read(name) for name in z.namelist() if '/' in name and not name.endswith('/')}
    current={str(f.relative_to(root)):f.read_bytes() for f in root.rglob('*') if f.is_file()}
    changed={name for name in originals.keys()&current.keys() if originals[name]!=current[name]}
    added=set(current)-set(originals)
    ck('no v80 files missing', not (set(originals)-set(current)))
    ck('changed files only script/name/history',changed=={'scripts/main.gd','project.godot','DEVELOPMENT.md'})
    ck('added files only v81 documentation/tests',added=={'README_v81_ja.md','tools/v81_camera_scope_self_check.py'})
    ck('other scripts untouched',all(originals[n]==current[n] for n in originals if n.startswith('scripts/') and n!='scripts/main.gd'))
    ck('all model, asset, shader bytes unchanged',all(originals[n]==current[n] for n in originals if n.startswith(('assets/','blockbench/','shaders/'))))
    # Precisely ensure main.gd changed ONLY to scope-promotion and comment.
    originalmain=originals['scripts/main.gd'].decode()
    v81_without_comment=re.sub(r'(?m)^# v81: shared between _physics_process\(\) and _process\(\)\. The previous local\n# declaration was invisible from _process\(\), causing a GDScript parse error\.\n','',main)
    expected=originalmain.replace('var step_camera_start_yaw: float = 0.0\n', 'var step_camera_start_yaw: float = 0.0\nvar close_step_camera_this_frame: bool = false\n',1).replace('    var close_step_camera_this_frame: bool = stepping_this_frame and step_close_camera', '    close_step_camera_this_frame = stepping_this_frame and step_close_camera',1)
    ck('main.gd changes precisely the intended scope fix',v81_without_comment==expected)
print(f'{sum(ok for _,ok in checks)}/{len(checks)} PASS')
sys.exit(0 if all(x for _,x in checks) else 1)
