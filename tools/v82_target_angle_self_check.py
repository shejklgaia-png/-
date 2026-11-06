#!/usr/bin/env python3
"""v82 static regression, angular simulation, and unchanged-v81 checks.
No Godot runtime required or implied.
"""
from pathlib import Path
import math, sys, zipfile
root=Path(__file__).resolve().parents[1]
main=(root/'scripts/main.gd').read_text()
project=(root/'project.godot').read_text()
checks=[]
def ck(label,condition):
    checks.append((label,bool(condition)))
    print(('PASS' if condition else 'FAIL')+' '+label)
ck('named v82', 'v82 | Target-Relative Close Step Camera' in project)
ck('rendering method unchanged','renderer/rendering_method="gl_compatibility"' in project)
ck('ordinary camera rate unchanged', 'const CAMERA_FOLLOW_RATE: float = 1.65' in main and 'const CAMERA_MOVING_YAW_SCALE: float = 0.55' in main)
ck('original step speed unchanged', 'const STEP_CLOSE_SPEED: float = 8.0' in main and 'const STEP_SPEED: float = 10.0' in main)
ck('run/boost unchanged', 'const MOVEMENT_BOOST_MULTIPLIER: float = 1.5' in main and 'const MOVE_SPEED: float = 3.25' in main)
ck('damage knockback preserved','const DAMAGE_KNOCKBACK_DISTANCE: float = 1.20' in main)
ck('near-step guard still shared across functions','var close_step_camera_this_frame: bool = false' in main and 'close_step_camera_this_frame = stepping_this_frame and step_close_camera' in main)
ck('removed start-yaw clamp', 'step_camera_start_yaw' not in main and 'STEP_CLOSE_CAMERA_MAX_ORBIT_DEGREES' not in main)
ck('target-relative bearing constraint', 'var offset_from_player: float = wrapf(desired_yaw - player_bearing, -PI, PI)' in main and 'STEP_CLOSE_CAMERA_MAX_RELATIVE_DEGREES' in main)
ck('slew rate limit', 'STEP_CLOSE_CAMERA_MAX_TURN_RATE_DEGREES' in main and 'clampf(yaw_to_go, -turn_limit, turn_limit)' in main)
ck('release guard enabled', 'close_step_camera_recovery_remaining = STEP_CLOSE_CAMERA_RECOVERY_SECONDS' in main and 'close_step_camera_recovery_remaining - delta' in main)
ck('new drag cancels release guard', 'close_step_camera_recovery_remaining = 0.0\n    gesture_suppressed_from_damage' in main)
ck('far step keeps normal camera branch', 'elif running:\n        # IMPORTANT: during a drag' in main and '        _enforce_screen_edge(bearing)' in main)
ck('frame fit still called', '    _fit_full_frame()\n    _place_camera()' in main)
ck('no force edge in protected camera branch', all('_enforce_screen_edge(' not in ln for ln in main.split('if protect_close_step and separation > 0.08:')[1].split('    elif running:')[0].splitlines() if not ln.strip().startswith('#')))
ck('no new viewport blur', 'SubViewport.new()' not in main)
ck('enemy bullets intact', 'var fire_interval_min: float = 2.0' in (root/'scripts/enemy_shooter.gd').read_text() and 'var travel_speed: float = 12.0' in (root/'scripts/enemy_projectile.gd').read_text())

# Basic numerical emulation of the GDScript helper, including seam crossing.
def wrap(angle): return (angle+math.pi)%(2*math.pi)-math.pi
def clamp(x,a,b): return max(a,min(b,x))
def lerp_angle(a,b,weight): return a+wrap(b-a)*weight
def helper(camera_yaw, bearing, delta, max_angle_deg=65.0, max_turn_deg=300.0):
    easing=1-math.exp(-1.65*delta)
    desired=lerp_angle(camera_yaw,bearing,easing*.55)
    offset=wrap(desired-bearing)
    bound=bearing+clamp(offset,-math.radians(max_angle_deg),math.radians(max_angle_deg))
    to_go=wrap(bound-camera_yaw)
    return camera_yaw+clamp(to_go,-math.radians(max_turn_deg)*delta,math.radians(max_turn_deg)*delta)
# Starting with a typical idle separation, ensure the target/player offset
# does not grow to > 120 degrees when a player moves 2m along an 8m/s step.
for radius in (1.3, 1.8, 2.4):
    for side in (-1,1):
        dt=1/60; yaw=math.radians(20) # start yaw vs target=40 degree delta
        bearing=math.radians(-20)
        duration=.25
        peak=0.0; max_delta=0.0
        for frame in range(round(duration/dt)):
            bearing+=side*(8.0/radius)*dt
            last=yaw
            yaw=helper(yaw,bearing,dt)
            peak=max(peak,abs(math.degrees(wrap(yaw-bearing))))
            max_delta=max(max_delta,abs(math.degrees(wrap(yaw-last))))
        ck(f'close step r={radius:.1f}m side={side}: 65+small angle cap',peak<=75.0)
        ck(f'close step r={radius:.1f}m side={side}: slew <=5deg/frame',max_delta<=5.0001)
# A wraparound crossing from 179 to -179 should be a short rotation, not a 360 turn.
new_angle=helper(math.radians(179),math.radians(-179),1/60)
ck('angle wrapping at +/-180',abs(math.degrees(wrap(new_angle-math.radians(179))))<5)

base_archive=root.parent/'sera_portrait_godot_melee_v81_close_step_camera_scope_fix.zip'
if base_archive.is_file():
    with zipfile.ZipFile(base_archive) as z:
        base={name.split('/',1)[1]:z.read(name) for name in z.namelist() if '/' in name and not name.endswith('/')}
    cur={f.relative_to(root).as_posix():f.read_bytes() for f in root.rglob('*') if f.is_file()}
    changed={n for n in base.keys()&cur.keys() if base[n]!=cur[n]}
    added=set(cur)-set(base)
    ck('all v81 project files kept', not(set(base)-set(cur)))
    ck('only intended originals changed',changed=={'scripts/main.gd','project.godot','DEVELOPMENT.md'})
    ck('only intended new files',added=={'README_v82_ja.md','tools/v82_target_angle_self_check.py'})
    ck('model/animations identical',all(base[n]==cur[n] for n in base if n.startswith(('blockbench/','assets/'))))
    ck('AI, input, animation, effects scripts identical',all(base[n]==cur[n] for n in base if n.startswith('scripts/') and n!='scripts/main.gd'))
print(f'{sum(ok for _,ok in checks)}/{len(checks)} PASS')
sys.exit(0 if all(ok for _,ok in checks) else 1)
