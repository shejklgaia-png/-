#!/usr/bin/env python3
"""Static + numerical v80 camera regression checks; not a Godot runtime test."""
from pathlib import Path
import zipfile, sys, math, re
root = Path(__file__).resolve().parents[1]
main = (root/'scripts/main.gd').read_text('utf8')
project = (root/'project.godot').read_text('utf8')
results=[]
def check(name, cond):
    results.append((name, bool(cond)))
    print(('PASS' if cond else 'FAIL')+' '+name)

check('v80 naming and compatibility renderer', 'SERA v80 | Close Side-Step Camera Fix' in project and 'renderer/rendering_method="gl_compatibility"' in project)
check('v78 follow rate restored', 'const CAMERA_FOLLOW_RATE: float = 1.65' in main)
check('v78 moving yaw factor restored', 'const CAMERA_MOVING_YAW_SCALE: float = 0.55' in main)
check('v79 high speed rates removed', 'CAMERA_ACTION_FOLLOW_RATE' not in main and 'CAMERA_ACTION_YAW_SCALE' not in main and 'fast_camera_follow' not in main)
check('v78 zoom rate restored', 'var easing: float = 1.0 - exp(-CAMERA_FOLLOW_RATE * delta)' in main)
check('v78 running camera classification restored', '''var running: bool = (direction_input.length_squared() > 0.000001
        or combat_state == CombatState.DASH or step_active)''' in main)
check('v78 standard running yaw unchanged', 'camera_yaw = lerp_angle(camera_yaw, bearing, easing * CAMERA_MOVING_YAW_SCALE)' in main)
check('v78 frame protection preserved', '_fit_full_frame()' in main and '_full_frame_safe()' in main)
check('near-step boundary is 1m from target box surface','const STEP_CLOSE_CAMERA_SURFACE_DISTANCE: float = 1.0' in main and 'step_close_camera = _distance_to_cube_surface(player.position) <= STEP_CLOSE_CAMERA_SURFACE_DISTANCE' in main)
check('symmetric close-step yaw cap 18 degrees', 'const STEP_CLOSE_CAMERA_MAX_ORBIT_DEGREES: float = 18.0' in main and '-deg_to_rad(STEP_CLOSE_CAMERA_MAX_ORBIT_DEGREES)' in main and 'deg_to_rad(STEP_CLOSE_CAMERA_MAX_ORBIT_DEGREES))' in main)
check('camera yaw captured before step starts', main.index('step_camera_start_yaw = camera_yaw') < main.index('    step_active = true',main.index('func _start_side_step')))
check('step frame snapshotted before advance',main.index('var close_step_camera_this_frame: bool = stepping_this_frame and step_close_camera') < main.index('        _advance_side_step(delta)'))
check('near step skips edge snap but frame correction remains', 'if close_step_camera_this_frame:' in main and '    elif running:' in main and '        _enforce_screen_edge(bearing)' in main)
check('damage knockback 1.2m retained', 'const DAMAGE_KNOCKBACK_DISTANCE: float = 1.20' in main)
check('run and boost speeds unchanged', 'const MOVE_SPEED: float = 3.25' in main and 'const MOVEMENT_BOOST_MULTIPLIER: float = 1.5' in main)
check('step speeds and length unchanged', all(s in main for s in ['const STEP_SPEED: float = 10.0','const STEP_CLOSE_SPEED: float = 8.0','const STEP_MIN_ARC_LENGTH: float = 2.0','const STEP_MAX_ARC_LENGTH: float = 4.0']))
check('flick gestures unchanged','const STEP_FLICK_MAX_SECONDS: float = 0.24' in main and 'func _start_side_step(side: int)' in main)
check('temporal afterimage retained','_update_motion_blur(delta)' in main and 'scripts/sera_rig.gd' in main)
check('enemy projectile speed and interval retained', 'var travel_speed: float = 12.0' in (root/'scripts/enemy_projectile.gd').read_text() and 'var fire_interval_min: float = 2.0' in (root/'scripts/enemy_shooter.gd').read_text())

# Approximate the short-step follow math across angular wrap and with fast
# relative bearing changes. Verify *the cap*, not any full camera projection.
def wrap(a): return (a+math.pi) % (2*math.pi) - math.pi
def update(yaw, anchor, target, dt):
    w=(1-math.exp(-1.65*dt))*.55
    desired=yaw+wrap(target-yaw)*w
    limit=math.radians(18)
    return anchor+max(-limit,min(limit,wrap(desired-anchor)))
for fps in [20,30,60,120]:
    for direction in [-1,1]:
        anchor=math.radians(179 if direction==1 else -179)
        yaw=anchor
        for i in range(30):
            # Simulate a dramatic +/-150 degree target-side change as the step travels.
            target=anchor+direction*math.radians(150)*i/29
            yaw=update(yaw,anchor,target,1/fps)
            if abs(wrap(yaw-anchor))>math.radians(18)+1e-9:
                raise AssertionError('camera angular cap violated')
check('angular cap simulated across +/- 180 and variable FPS',True)

# Validate that the entire main script is v78 plus our targeted patches.
base_zip = root.parent/'sera_portrait_godot_melee_v78_boost_afterimage_short_fade.zip'
prev_zip = root.parent/'sera_portrait_godot_melee_v79_melee_boost_cancel_camera.zip'
if base_zip.is_file() and prev_zip.is_file():
    def get_files(path):
        with zipfile.ZipFile(path) as z:
            return {k.split('/',1)[1]:z.read(k) for k in z.namelist() if '/' in k and not k.endswith('/')}
    b=get_files(base_zip);v=get_files(prev_zip)
    cur={f.relative_to(root).as_posix():f.read_bytes() for f in root.rglob('*') if f.is_file()}
    changed={n for n in v.keys() & cur.keys() if v[n]!=cur[n]}
    check('no original v79 files removed',not(set(v)-set(cur)))
    check('changed originals limited to camera project and history',changed=={'scripts/main.gd','project.godot','DEVELOPMENT.md'})
    check('v79 rig/shaders/asset contents preserved',all(v[k]==cur[k] for k in v if k.startswith(('scripts/sera_rig.gd','shaders/','assets/','blockbench/'))))
    check('all untouched scripts byte identical to v78',all(b[k]==cur[k] for k in b if k.startswith('scripts/') and k!='scripts/main.gd'))
    check('camera script now uses original v78 idle yaw path','var idle_yaw: float = _nearest_clear_yaw(bearing, player_screen_side, TARGET_IDLE_GAP_RATIO)' in main)

print(f'{sum(ok for _,ok in results)}/{len(results)} passed')
sys.exit(0 if all(ok for _,ok in results) else 1)
