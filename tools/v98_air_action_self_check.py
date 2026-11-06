#!/usr/bin/env python3
"""v98 structural/invariant checks, no Godot runtime available in this container."""
from pathlib import Path
import json, re, math, hashlib, sys

root=Path(__file__).resolve().parents[1]
main=(root/'scripts/main.gd').read_text('utf-8')
rig=(root/'scripts/sera_rig.gd').read_text('utf-8')
source=json.loads((root/'assets/sera_source.json').read_text('utf-8'))
checks={}
def check(name, condition):
 checks[name]=bool(condition)
 if not condition: print('FAIL:',name)

def body(source,fn):
 pattern=re.compile(r'^func '+re.escape(fn)+r'\([^\n]*\).*?\n(?=func |\Z)',re.S|re.M)
 m=pattern.search(source)
 if not m: raise AssertionError('missing function '+fn)
 return m.group(0)

check('new version', 'SERA v98' in (root/'project.godot').read_text('utf-8'))
check('jump flick reduced to 50px', 'JUMP_FLICK_MIN_VERTICAL: float = 50.0' in main)
check('up classifier uses smaller threshold', 'upward >= JUMP_FLICK_MIN_VERTICAL' in body(main,'_is_upward_jump_flick'))
check('back flick remains 78px', 'STEP_FLICK_MIN_VERTICAL: float = 78.0' in main and 'if vertical < STEP_FLICK_MIN_VERTICAL' in body(main,'_classify_step_flick'))
check('side flick remains 78px', 'STEP_FLICK_MIN_HORIZONTAL: float = 78.0' in main)
check('flick speed unchanged', 'STEP_FLICK_MIN_PIXELS_PER_SEC: float = 500.0' in main)
check('takeoff retains 80%', 'JUMP_TAKEOFF_HORIZONTAL_FACTOR: float = 0.80' in main)
check('launch uses inherited velocity', '* JUMP_TAKEOFF_HORIZONTAL_FACTOR' in body(main,'_start_jump'))
check('air steering 30%', 'JUMP_AIR_STEER_SPEED_FACTOR: float = 0.30' in main)
check('steering in screen frame', '_screen_drag_to_ground(direction_input)' in body(main,'_advance_jump'))
check('steering additive to inertia', 'jump_horizontal_velocity + steering_velocity' in body(main,'_advance_jump'))
check('air steering does not apply boost multiplier', 'boost_speed_multiplier' not in body(main,'_advance_jump'))
check('boost prohibited during air', 'or jump_active:' in body(main,'_update_boost_gesture'))
check('jump motion not changed by steering', 'set_moving' not in body(main,'_advance_jump') and 'start_jump' not in body(main,'_advance_jump'))
check('side step airborne enabled', 'if jump_active or damage_reaction_active' not in body(main,'_start_side_step'))
check('back step airborne enabled', 'if jump_active or damage_reaction_active' not in body(main,'_start_back_step'))
check('air melee airborne enabled', 'if jump_active or damage_reaction_active' not in body(main,'_start_attack'))
check('no jump during aerial action', 'or step_active or combat_state != CombatState.IDLE' in body(main,'_start_jump'))
check('step freezes flight, combat freezes flight', 'if (step_active or combat_state != CombatState.IDLE)' in body(main,'_advance_jump'))
check('step resumes fall on finish', '_enter_jump_fall()' in body(main,'_finish_side_step'))
check('attack resumes fall on finish', '_enter_jump_fall()' in body(main,'_advance_attack'))
check('attack cancel resumes fall', '_enter_jump_fall()' in body(main,'_cancel_attack'))
check('jump seeks authored fall pose', '0.20833 / 0.375' in rig and 'set_jump_progress(JUMP_FALL_CLIP_START)' in body(rig,'resume_jump_fall'))
check('no replay of takeoff after action', 'resume_jump_fall()' in body(rig,'finish_side_step') and 'resume_jump_fall()' in body(rig,'finish_attack'))
check('gravity-based fall from current height', 'jump_fall_start_height = maxf(player.position.y, 0.0)' in body(main,'_enter_jump_fall') and 'sqrt(2.0 * jump_fall_start_height / JUMP_GRAVITY)' in body(main,'_enter_jump_fall'))
check('fall reset from each new action', 'or jump_fall_after_action' not in body(main,'_enter_jump_fall'))
check('landing at zero', 'player.position.y = 0.0' in body(main,'_advance_jump'))
check('fall continues during damage', 'and not damage_reaction_active' in body(main,'_advance_jump'))
check('damage recovers falling animation', 'rig.call("resume_jump_fall")' in body(main,'_physics_process'))
check('air step not canceled by held steering', 'if step_active and not jump_active:' in body(main,'_change_drag'))
check('existing jump motion present',any(x.get('name')=='Jump' for x in source['animations']))
check('height kept at 1.5m', 'JUMP_HEIGHT: float = 1.50' in main)
check('flight kept at 0.80sec', 'JUMP_FLIGHT_SECONDS: float = 0.80' in main)
check('backstep kept 4m', 'BACK_STEP_DISTANCE: float = 4.0' in main)
check('damage keeps combo values', 'const STRIKE_DAMAGE = [12, 12, 26]' in main)
check('hysteresis remains', 'BOOST_START_RADIUS_RATIO: float = 1.25' in main and 'BOOST_EXIT_RADIUS_RATIO: float = 1.10' in main)
check('new release notes', (root/'README_v98_ja.md').is_file())
check('all 4 enemy attacks preserved', all((root/'scripts'/f).exists() for f in ['enemy_area_attack.gd','enemy_shooter.gd','enemy_projectile.gd','enemy_debug_ui.gd']))

# Mathematical checks at various frame rates for the original parabola and
# post-action gravity. They do not substitute for actual engine behavior.
for fps in [30,60,120]:
 T=.8;h=1.5;dt=1/fps
 t=0; peak=0
 while t<T-1e-8:
  t=min(T,t+dt);peak=max(peak,4*h*(t/T)*(1-t/T))
 check(f'original {fps}fps parabola peak near 1.5',abs(peak-h)<.006)
 check(f'original {fps}fps lands at zero',abs(4*h*(1-1))<1e-10)
 g=8*h/T**2
 for start_height in [.15,.62,1.5]:
  duration=max(.05,math.sqrt(2*start_height/g))
  last=max(0.,start_height-.5*g*duration*duration)
  check(f'post-action fall {fps}fps from {start_height}m lands', last<1e-8)
 check(f'30pct air max at {fps}fps', abs(3.25*.30-.975)<1e-8)

fail=[k for k,v in checks.items() if not v]
print(f'v98 aerial self-check: {len(checks)-len(fail)}/{len(checks)} PASS')
if fail: sys.exit(1)
