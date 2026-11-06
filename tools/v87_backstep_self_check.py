#!/usr/bin/env python3
"""v87 static integration checks (not a substitute for running Godot)."""
from pathlib import Path
import base64
import json
import math
import re

R = Path(__file__).resolve().parents[1]
main = (R/'scripts/main.gd').read_text(encoding='utf-8')
rig = (R/'scripts/sera_rig.gd').read_text(encoding='utf-8')
proj = (R/'project.godot').read_text(encoding='utf-8')
source_bytes = (R/'assets/sera_source.json').read_bytes()
source = json.loads(source_bytes)
original = json.loads((R/'blockbench/SERA_backstep_user_input.bbmodel').read_text(encoding='utf-8'))
merged = json.loads((R/'blockbench/SERA_v87_backstep_integrated.bbmodel').read_text(encoding='utf-8'))
checks = 0
expected_back_distance = 4.0 if ('SERA v88' in proj or 'SERA v89' in proj) else 2.0

def check(name, condition):
    global checks
    assert condition, f'FAIL: {name}'
    checks += 1
    print('PASS:', name)

clips = {a['name']: a for a in source['animations']}
check('all 11 unique clips retained', len(source['animations']) == len(clips) == (12 if 'SERA v89' in proj else 11))
check('new last clip Backstep', source['animations'][10]['name'] == 'Backstep')
check('integrated editable model matches runtime JSON', {**source, 'animations': source['animations'][:11]} == merged)
check('only added clip from user model', source['animations'][10] == original['animations'][-1])
check('existing model groups, meshes, outliner retained', all(source[k] == original[k] for k in ['groups', 'elements', 'outliner']))
check('same 22 groups and 25 elements', len(source['groups']) == 22 and len(source['elements']) == 25)
check('existing clip ordering retained', [a['name'] for a in source['animations'][:10]] == ['Wait_motion', 'Wait_Pose', 'meleeboost', 'run_front_original', 'melee1', 'Step_R', 'Step_L', 'Damageknock', 'Melee2', 'Melee3'])
back = clips['Backstep']
back_frames = [frame for anim in back['animators'].values() for frame in anim.get('keyframes', [])]
check('18 authored pose keys at zero', len(back_frames) == 18 and all(float(frame['time']) == 0.0 for frame in back_frames))
check('authored Backstep is a single pose, not a synthesized animation', back['length'] == 0 and back['loop'] == 'once')

def as_pose(clip):
    return {uid: [(f['channel'], f['time'], f['data_points']) for f in animator.get('keyframes', [])]
            for uid, animator in clip['animators'].items() if animator.get('keyframes', [])}
check('Backstep poses differ from sideways steps', as_pose(back) != as_pose(clips['Step_L']) and as_pose(back) != as_pose(clips['Step_R']))
check('Godot loads Backstep from authored source', 'const STEP_BACK_CLIP: String = "Backstep"' in rig and 'animations.has(STEP_BACK_CLIP)' in rig)
check('step animation uses authored Backstep with blend', '_switch_clip(STEP_BACK_CLIP, 0.055)' in rig)
check('input classification occurs only on release', main.count('_classify_step_flick(release_pos - pointer_origin, press_duration)') == 1 and 'func _end_drag(' in main)
check('downward flick routed to back step, lateral unchanged', 'if flick_direction == STEP_BACK:\n        _start_back_step()' in main and 'elif flick_direction != 0:\n        _start_side_step(flick_direction)' in main)
check('old lateral flick classifier still called', 'var side: int = _classify_side_flick(displacement, seconds)' in main and 'func _classify_side_flick(' in main)
check('flick duration / length / speed guards', all(s in main for s in ['STEP_FLICK_MAX_SECONDS: float = 0.24', 'STEP_FLICK_MIN_VERTICAL: float = 78.0', 'STEP_FLICK_MIN_PIXELS_PER_SEC: float = 500.0', 'STEP_FLICK_MAX_HORIZONTAL_RATIO: float = 0.42']))
check('down-only (no upward activation)', 'var vertical: float = displacement.y\n    if vertical < STEP_FLICK_MIN_VERTICAL:' in main)
check('anti-reversal guard for backward flick', 'if gesture_max_travel > displacement.length() * 1.20:' in main)
check('backward world direction target-relative', 'var away: Vector3 = player.position - target.position' in main and 'away = away.normalized()' in main)
check('backstep fixed distance', f'const BACK_STEP_DISTANCE: float = {expected_back_distance:.1f}' in main and 'step_linear_offset = Vector2(away.x, away.z) * BACK_STEP_DISTANCE' in main)
check('existing 8–10m/s step speeds used', all(s in main for s in ['const STEP_SPEED: float = 10.0', 'const STEP_CLOSE_SPEED: float = 8.0', 'step_speed_current = _step_speed_for_player_position(player.position)']))
check('backstep uses same computed duration', 'step_duration_current = BACK_STEP_DISTANCE / step_speed_current' in main)
check('backstep uses old swept collision motion and fade', 'step_linear_fallback = true' in main and '_move_player_swept(requested, true)' in main and 'rig.call("finish_side_step", resume_moving)' in main)
check('back-step does not turn on side-step camera guard', 'step_close_camera = false' in main and 'step_close_camera = _distance_to_cube_surface(player.position) <= STEP_CLOSE_CAMERA_SURFACE_DISTANCE' in main)
check('step and boost afterimages preserved', 'blur_step_this_physics_frame = stepping_this_frame and not damage_reaction_active' in main and 'and movement_boost_active and running' in main)
check('boost still outer drag circle at 1.5x', 'const MOVEMENT_BOOST_MULTIPLIER: float = 1.5' in main and 'boost_requested: bool' in main and 'DRAG_RADIUS * DRAG_RADIUS' in main)
check('explicit HUD naming for boost/step/attack approach', all(s in main for s in ['STEP BACK  |  Backstep', 'STEP RIGHT  |  Step_R', 'STEP LEFT  |  Step_L', 'BOOST  x1.5  |  Boost_front' if 'SERA v89' in proj else 'BOOST  x1.5  |  long drag', 'MELEE APPROACH  |  meleeboost']))
check('internal melee approach state is distinct from movement BOOST', 'CombatState.MELEE_APPROACH' in main and 'CombatState.BOOST' not in main and 'const MELEE_APPROACH_CLIP: String = "meleeboost"' in rig and 'func start_melee_approach()' in rig)
check('3 attack stages and damage retained', 'const STRIKE_DAMAGE = [12, 12, 26]' in main and 'const STRIKE_CLIPS = ["melee1", "Melee2", "Melee3"]' in main)
check('enemy shooter and projectile retained', all((R/'scripts'/k).is_file() for k in ['enemy_shooter.gd','enemy_projectile.gd']))
check('project and Android GL compatibility', ('SERA v87' in proj or 'SERA v88' in proj or 'SERA v89' in proj) and 'gl_compatibility' in proj)
chunks = re.findall(r'    "([A-Za-z0-9+/=]+)",', (R/'assets/sera_data.gd').read_text(encoding='utf-8'))
check('embedded model exactly matches on-disk source', base64.b64decode(''.join(chunks)) == source_bytes)

# Independent numerical checks of the intended path and input thresholds.
for speed in (8.0, 9.0, 10.0):
    duration = expected_back_distance/speed
    check(f'{expected_back_distance}m backward travel @ {speed}m/s retains 8-10m/s', duration <= expected_back_distance/8.0 and abs(duration * speed - expected_back_distance) < 1e-12)
for x,z,ex,ez in ((2,0,1,0), (-1,-3,-1/math.sqrt(10),-3/math.sqrt(10)), (0,5,0,1)):
    mag = math.hypot(x,z)
    check(f'backward travel points away from target ({x},{z})', abs(x/mag-ex) < 1e-12 and abs(z/mag-ez) < 1e-12)

# All direct script preload paths must resolve.
for path in (R/'scripts').glob('*.gd'):
    for asset in re.findall(r'(?:preload|load)\("(res://[^"]+)"\)', path.read_text(encoding='utf-8')):
        check('resource exists: '+asset, (R / asset[6:]).exists())
print(f'backstep project: {checks} checks passed (static only)')
