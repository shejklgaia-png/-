#!/usr/bin/env python3
"""v79 camera/action-state static and numerical guards (not a Godot run)."""
from pathlib import Path
from zipfile import ZipFile
import hashlib
import math
import re

root=Path(__file__).resolve().parents[1]
project=(root/'project.godot').read_text(encoding='utf8')
main=(root/'scripts/main.gd').read_text(encoding='utf8')
checks=[]
def ck(label, ok):
    checks.append((label,bool(ok)))
    print(('PASS' if ok else 'FAIL')+' '+label)
def func(name):
    m=re.search(r'^func '+re.escape(name)+r'\([^\n]*\)[\s\S]*?(?=^func |\Z)',main,re.M)
    assert m, name
    return m.group()
process=func('_process')
ck('v79 project and original GL compatibility renderer', 'SERA v79 | Melee Boost Cancel Camera' in project and 'renderer/rendering_method="gl_compatibility"' in project)
ck('melee startup, dash and strike all retain active camera tracking', 'var action_camera_active: bool = combat_state != CombatState.IDLE' in process and 'drag_camera_active or action_camera_active or step_active' in process)
ck('melee and boost move select fast follow', 'or (drag_camera_active and movement_boost_active)' in process)
ck('normal camera constants preserved', all(x in main for x in ['const CAMERA_FOLLOW_RATE: float = 1.65','const CAMERA_MOVING_YAW_SCALE: float = 0.55','const CAMERA_IDLE_RECENTER_RATE: float = 1.05']))
ck('fast camera constants defined', 'const CAMERA_ACTION_FOLLOW_RATE: float = 6.0' in main and 'const CAMERA_ACTION_YAW_SCALE: float = 0.85' in main)
ck('fast selection governs yaw and zoom', 'CAMERA_ACTION_FOLLOW_RATE if fast_camera_follow else CAMERA_FOLLOW_RATE' in process and 'CAMERA_ACTION_YAW_SCALE if fast_camera_follow else CAMERA_MOVING_YAW_SCALE' in process and 'lerpf(camera_radius, preferred_radius, easing * 0.9)' in process)
ck('frame fit and idle stabilization preserved', '_fit_full_frame()' in process and '_enforce_screen_edge(bearing)' in process and '_nearest_clear_yaw(bearing, player_screen_side, TARGET_IDLE_GAP_RATIO)' in process)
ck('camera follows physics-updated positions', 'player.global_position.x - target.global_position.x' in process and 'player.global_position.z - target.global_position.z' in process)
ck('melee cancel switches to idle for the drag boost', '_cancel_attack()' in func('_change_drag') and 'combat_state = CombatState.IDLE' in func('_cancel_attack') and 'movement_boost_active = boost_requested' in func('_change_drag'))
ck('same 1.5x boost & melee dash speed', 'const MOVEMENT_BOOST_MULTIPLIER: float = 1.5' in main and 'const MELEE_DASH_SPEED: float = 11.5' in main)
ck('same step falloff & distance', all(x in main for x in ['const STEP_SPEED: float = 10.0','const STEP_CLOSE_SPEED: float = 8.0','const STEP_MIN_ARC_LENGTH: float = 2.0','const STEP_MAX_ARC_LENGTH: float = 4.0']))
ck('original target projection order retained',process.rfind('_update_target_marker_projection()')<process.rfind('_update_motion_blur(delta)'))
# Mirror the state gating and smoothing expressions across important transitions.
rate_normal=1.65; scale_normal=.55; rate_fast=6.0; scale_fast=.85
cases=[('standby',False,False,False,False),('normal_run',False,True,False,False),('step',False,False,True,False),('attack_boost_windup',True,False,False,False),('attack_dash',True,False,False,False),('attack_strike',True,False,False,False),('drag_boost_cancel',False,True,False,True)]
for name,action,drag,step,boost in cases:
    running=drag or action or step
    fast=action or (drag and boost)
    ck(name+' camera mode', (running,fast)==(name not in ('standby',),name in ('attack_boost_windup','attack_dash','attack_strike','drag_boost_cancel')))
for fps in [15,30,60,120]:
    d=1.0/fps
    normal=1-math.exp(-rate_normal*d)
    fast=1-math.exp(-rate_fast*d)
    ck(f'fast yaw/zoom stronger at {fps}fps',0<normal<fast<1 and fast*scale_fast>normal*scale_normal)
# Differences relative to current v78 ZIP, do not alter any other gameplay modules.
baseline=root.parent/'sera_portrait_godot_melee_v78_boost_afterimage_short_fade.zip'
if baseline.is_file():
    with ZipFile(baseline) as z:
        base={n.split('/',1)[1]:z.read(n) for n in z.namelist() if '/' in n and not n.endswith('/')}
    here={f.relative_to(root).as_posix():f.read_bytes() for f in root.rglob('*') if f.is_file()}
    changed={n for n in set(base)&set(here) if base[n]!=here[n]}
    added=set(here)-set(base)
    ck('no base files deleted',not(set(base)-set(here)))
    ck('only main.gd, project.godot and history changed',changed=={'scripts/main.gd','project.godot','DEVELOPMENT.md'})
    ck('only version note and self check added',added=={'README_v79_ja.md','tools/v79_camera_follow_self_check.py'})
    ck('all original scripts except main byte-identical',all(base[f]==here[f] for f in base if f.startswith('scripts/') and f!='scripts/main.gd'))
    ck('all models and visual resources byte-identical',all(base[f]==here[f] for f in base if f.startswith(('assets/','blockbench/','shaders/'))))
print(f"{sum(ok for _,ok in checks)}/{len(checks)} PASS")
raise SystemExit(0 if all(ok for _,ok in checks) else 1)
