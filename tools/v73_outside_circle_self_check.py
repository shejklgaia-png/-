#!/usr/bin/env python3
"""SERA v73 controller: static/layout/threshold/integrity checks (no Godot runtime)."""
from pathlib import Path
import math,re,zipfile,sys,hashlib
root=Path(__file__).resolve().parents[1]
base_path=root.parent.parent/'sera_portrait_godot_melee_v72_run_boost_ring.zip'
main=(root/'scripts/main.gd').read_text(encoding='utf-8')
ui=(root/'scripts/touch_overlay.gd').read_text(encoding='utf-8')
proj=(root/'project.godot').read_text(encoding='utf-8')
checks=[]
def check(desc, expression):
    ok=bool(expression)
    checks.append((desc,ok))
    print(('PASS  ' if ok else 'FAIL  ')+desc)
def const(s,name):
    m=re.search(r'const '+re.escape(name)+r': float = ([0-9.]+)',s)
    if not m: raise ValueError('Missing '+name)
    return float(m.group(1))

radius=const(main,'DRAG_RADIUS')
threshold=const(main,'BOOST_OUTSIDE_RADIUS_RATIO')
normal=const(main,'MOVE_SPEED')
boost=const(main,'MOVEMENT_BOOST_MULTIPLIER')
check('project version v73', 'SERA v73 | Outside Circle Boost 1.5x' in proj)
check('base circle uses old full outer radius',radius==168.0 and const(ui,'CONTROLLER_CHEVRON_NEAR_RATIO')>1.0)
check('boost trigger strictly outside disc',threshold==1.0 and '> DRAG_RADIUS * DRAG_RADIUS * BOOST_OUTSIDE_RADIUS_RATIO * BOOST_OUTSIDE_RADIUS_RATIO' in main)
check('no legacy 62% inner threshold','BOOST_RING_START_RATIO' not in main and 'CONTROLLER_INNER_RING_RADIUS_RATIO' not in ui)
check('analog run scaled to complete disc','var delta: Vector2 = (pos - pointer_origin) / DRAG_RADIUS' in main)
check('analog strength capped at unity','direction_input = delta.limit_length(1.0)' in main)
check('run and boost max speeds unchanged',normal==3.25 and boost==1.5 and math.isclose(normal*boost,4.875))
check('boost multiplies only intended horizontal movement','player.velocity = world_move * MOVE_SPEED * speed_multiplier' in main)
check('boost reverts immediately upon entering circle','if movement_boost_active != boost_requested:' in main and 'movement_boost_active = boost_requested' in main)
check('boost off on touch start and release',main.count('movement_boost_active = false')==2 and main.count('touch_ui.call("set_movement_boost", false)')==2)
check('floating controller origin/radius remains wired','touch_ui.call("show_drag", pointer_origin, pointer_location, DRAG_RADIUS)' in main)
check('single filled disc', 'draw_circle(anchor_point, radius, Color(0.15, 0.60, 0.68, 0.08))' in ui)
check('v70 center-to-finger line','draw_line(anchor_point, knob_center, low, 5.0, true)' in ui)
check('marker travels to fingertip within circle','anchor_point + (finger_point - anchor_point).limit_length(radius)' in ui)
check('finger marker and existing accent','draw_circle(knob_center, CONTROLLER_FINGER_DOT_RADIUS, Color(0.13, 0.54, 0.61, 0.45))' in ui)
check('four cardinal paired chevrons','for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:' in ui and ui.count('_draw_chevron(anchor_point, direction, radius * CONTROLLER_CHEVRON_')==2)
near=const(ui,'CONTROLLER_CHEVRON_NEAR_RATIO'); far=const(ui,'CONTROLLER_CHEVRON_FAR_RATIO')
check('chevron shapes wholly outside rim',near-0.065*0.5>1.0 and far>near and far+0.065*0.5<1.40)
check('removed central disk and inner ring','ring_thickness' not in ui and 'CONTROLLER_KNOB_TRAVEL_RATIO' not in ui and 'ring_middle' not in ui)
check('UI feedback on active mode','var rim_color: Color = accent if movement_boost_active else low' in ui and '_draw_move_mode_indicator(accent, rim_color)' in ui)
check('UI overlay and header still show RUN/BOOST','BOOST  1.5x' in ui and 'RUN  1.0x' in ui and 'MOVE BOOST  x1.5' in main and 'RUN  x1.0' in main)
check('no controller images or input capture','draw_texture' not in ui and 'touch_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE' in main)
check('original operation zone unchanged',all(x in ui for x in ('OPERATION_ZONE_TOP_RATIO: float = 0.75','OPERATION_ZONE_SOLID_RATIO: float = 0.92','Color(0.494, 0.510, 0.533, 0.85)')))
check('target marker unchanged','draw_arc(mark, lock_radius, start, start + LOCK_ARC_SWEEP' in ui)
check('existing enemy speed/interval', 'var fire_interval_min: float = 2.0' in (root/'scripts/enemy_shooter.gd').read_text('utf-8') and 'var travel_speed: float = 12.0' in (root/'scripts/enemy_projectile.gd').read_text('utf-8'))
check('knockback unchanged', 'const DAMAGE_KNOCKBACK_DISTANCE: float = 1.20' in main and 'const DAMAGE_KNOCKBACK_DURATION: float = 0.24' in main)
check('flick/tap semantics unchanged','_classify_side_flick(release_pos - pointer_origin, press_duration)' in main and '_start_side_step(flick_side)' in main and '_start_attack()' in main)
for dist,mode in [(0,'RUN'),(100,'RUN'),(167.9,'RUN'),(168,'RUN'),(168.0001,'BOOST'),(210,'BOOST'),(500,'BOOST')]:
    actual='BOOST' if dist*dist > radius*radius*threshold*threshold else 'RUN'
    check(f'{dist:g}px drag -> {mode}',actual==mode)
for d,expected in [(0,0),(84,1.625),(168,3.25),(169,4.875),(500,4.875)]:
    actual=normal*min(1,d/radius)*(boost if d>radius*threshold else 1.0)
    check(f'{d}px analog/run speed = {expected:g}m/s',math.isclose(actual,expected,rel_tol=1e-6))
if base_path.is_file():
    with zipfile.ZipFile(base_path) as z:
        base={name.split('/',1)[1]:z.read(name) for name in z.namelist() if '/' in name and not name.endswith('/')}
    curr={p.relative_to(root).as_posix():p.read_bytes() for p in root.rglob('*') if p.is_file()}
    changed={n for n in base.keys() & curr.keys() if base[n]!=curr[n]}
    removed=set(base)-set(curr)
    added=set(curr)-set(base)
    allowed_changed={'scripts/main.gd','scripts/touch_overlay.gd','project.godot','DEVELOPMENT.md'}
    check('no base files removed',not removed)
    check('only intended existing files changed',changed==allowed_changed)
    check('only documentation and test added',added=={'README_v73_ja.md','tools/v73_outside_circle_self_check.py'})
    # Untouched features remain bit-identical (includes shaders/Blockbench/resources).
    check('all other base files byte-identical',all(base[n]==curr[n] for n in base if n not in changed))
    old_main=base['scripts/main.gd'].decode('utf8')
    for start,end in [('_classify_side_flick','_start_side_step'),('_start_side_step','_finish_side_step'),('_advance_side_step','_move_player_swept'),('_on_enemy_projectile_hit','_begin_damage_reaction'),('_advance_damage_knockback','_advance_projectile_hit_overlay')]:
        def segment(s):return s.split('func '+start+'(',1)[1].split('func '+end+'(',1)[0]
        check(start+' unchanged',segment(old_main)==segment(main))
else:
    print('INFO: original v72 archive unavailable; archive diff skipped')
print(f'\n{sum(ok for _,ok in checks)}/{len(checks)} passed')
if not all(ok for _,ok in checks):sys.exit(1)
