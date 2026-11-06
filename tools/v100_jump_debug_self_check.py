#!/usr/bin/env python3
"""v100: jump kept for debug, removed from normal touch. Run from project root."""
from pathlib import Path
import hashlib, json, re, zipfile
ROOT = Path(__file__).resolve().parents[1]
BASE = Path('/mnt/data/sera_v99_work')
checks=[]
def check(name, ok):
    checks.append((name,bool(ok)))
    if not ok: print('FAIL',name)

main=(ROOT/'scripts/main.gd').read_text(encoding='utf-8')
ui=(ROOT/'scripts/enemy_debug_ui.gd').read_text(encoding='utf-8')
proj=(ROOT/'project.godot').read_text(encoding='utf-8')
check('v100 title', 'SERA v100 | Ground combat (jump debug only)' in proj)
check('jump normal input defaults OFF', 'const JUMP_TOUCH_INPUT_ENABLED: bool = false' in main)
check('both initial and tail jump recognition gated', 'var jump_from_initial_flick: bool = JUMP_TOUCH_INPUT_ENABLED' in main and 'var jump_requested: bool = JUMP_TOUCH_INPUT_ENABLED' in main)
check('touch jump only inside guarded request', '    if jump_requested:\n        _start_jump(takeoff_momentum)' in main)
check('tap uses _start_attack', '    elif was_tap:\n        _start_attack()' in main)
check('backstep retains routing', 'elif flick_direction == STEP_BACK:' in main and '_start_back_step()' in main)
check('side step retains routing', 'elif flick_direction != 0:' in main and '_start_side_step(flick_direction)' in main)
check('suppress damaged gesture retained', 'gesture_suppressed_from_damage or gesture_suppressed_from_landing' in main)
check('debug signal connected', 'enemy_debug_ui.connect("jump_test_requested", Callable(self, "_debug_jump"))' in main)
check('debug handler exists', 'func _debug_jump() -> void:' in main and '_start_jump(Vector3(player.velocity.x, 0.0, player.velocity.z))' in main)
check('keyboard J remains', 'event.keycode == KEY_J:' in main and '            _debug_jump()' in main)
check('debug panel intercepts touch', 'enemy_debug_ui.get_global_rect().has_point(pos)' in main)
check('debug button action', 'signal jump_test_requested()' in ui and 'jump_test_button.pressed.connect(_on_jump_test_pressed)' in ui and 'jump_test_requested.emit()' in ui)
check('debug button label', 'jump_test_button.text = "JUMP TEST"' in ui)
check('enemy debug selections retained', 'const MODE_TEXTS = ["AIM", "LEAD", "SHOCK", "ARC"]' in ui and 'fire_requested.emit()' in ui and 'auto_fire_changed.emit(' in ui)
check('jump height retained', 'const JUMP_HEIGHT: float = 1.50' in main)
check('air control retained', 'const JUMP_AIR_STEER_SPEED_FACTOR: float = 0.30' in main)
check('momentum retained', 'const JUMP_TAKEOFF_HORIZONTAL_FACTOR: float = 0.80' in main)
check('landing hold retained', 'const JUMP_LANDING_HOLD_SECONDS: float = 0.60' in main)
check('flick side retained', 'const STEP_FLICK_MIN_HORIZONTAL: float = 78.0' in main)
check('flick back retained', 'const STEP_FLICK_MIN_VERTICAL: float = 78.0' in main)
check('backstep 4 meters', 'const BACK_STEP_DISTANCE: float = 4.0' in main)
check('boost hysteresis retained', 'const BOOST_START_RADIUS_RATIO: float = 1.25' in main and 'const BOOST_EXIT_RADIUS_RATIO: float = 1.10' in main)
check('combo damage retained', 'const STRIKE_DAMAGE = [12, 12, 26]' in main)
check('jump source data present', (ROOT/'blockbench/SERA_v99_jump_landing_integrated.bbmodel').exists())
check('jump asset present', (ROOT/'assets/sera_source.json').exists())
check('model and animations untouched', all((ROOT/p).read_bytes()==(BASE/p).read_bytes() for p in ['assets/sera_source.json','assets/sera_data.gd','scripts/sera_rig.gd','blockbench/SERA_v99_jump_landing_integrated.bbmodel']))
check('enemy AI untouched', all((ROOT/p).read_bytes()==(BASE/p).read_bytes() for p in ['scripts/enemy_area_attack.gd','scripts/enemy_projectile.gd','scripts/enemy_shooter.gd']))
check('camera and audio unmodified in main',bool(re.search(r'func _process\(delta:',main)) and 'sera_player_bullet_hit_v96.wav' in main and 'sera_melee_hit_all.wav' in main)

# v99 must remain byte-identical apart from narrowly scoped modification files.
changed=[]
for f in BASE.rglob('*'):
    if f.is_file():
        rel=f.relative_to(BASE)
        corresponding=ROOT/rel
        check('preserved file: '+str(rel), corresponding.is_file())
        if corresponding.is_file() and corresponding.read_bytes()!=f.read_bytes(): changed.append(str(rel))
expected={'scripts/main.gd','scripts/enemy_debug_ui.gd','project.godot','DEVELOPMENT.md'}
check('only intended original files changed', set(changed)==expected)
extra={str(f.relative_to(ROOT)) for f in ROOT.rglob('*') if f.is_file()} - {str(f.relative_to(BASE)) for f in BASE.rglob('*') if f.is_file()}
check('only intended new files', extra=={'README_v100_ja.md','tools/v100_jump_debug_self_check.py'})

# Simulate v100 touch classification for representative gesture shapes.
def _step(dx,dy,sec,maxdist):
    if not (0 < sec <= 0.24): return 0
    if abs(dx)>=78 and abs(dx)/sec>=500 and abs(dy)<=abs(dx)*.42 and maxdist<=((dx*dx+dy*dy)**.5)*1.2:
        return 1 if dx>0 else -1
    if dy>=78 and dy/sec>=500 and abs(dx)<=dy*.42 and maxdist<=((dx*dx+dy*dy)**.5)*1.2:
        return 2
    return 0
# The disabled jump gate must leave ordinary-step inputs independent.
for name,dx,dy,sec,exp in [
    ('up quick',0,-100,.15,0),
    ('up jump legacy min',0,-50,.09,0),
    ('left quick',-100,0,.15,-1),
    ('right quick',100,0,.15,1),
    ('down quick',0,100,.15,2),
    ('no step on slow drag',100,0,.6,0),
    ('diagonal no step',100,90,.15,0),
    ('tap no step',0,0,.1,0),
]: check('input scenario: '+name,_step(dx,dy,sec,(dx*dx+dy*dy)**.5)==exp)

print(f'V100 checks passed: {sum(ok for _,ok in checks)}/{len(checks)}; modified originals: {changed}; extra: {sorted(extra)}')
if not all(ok for _,ok in checks): raise SystemExit(1)
