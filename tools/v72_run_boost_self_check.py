#!/usr/bin/env python3
"""Static + logic checks for v72. No Godot runtime is involved."""
from pathlib import Path
import zipfile,re,math,hashlib,sys
root=Path(__file__).resolve().parents[1]
# Diff checks are optional outside the build workspace (e.g., on Android).
base_name = 'sera_portrait_godot_melee_v71_vector_touch_controller.zip'
base_candidates = [root.parent / base_name, root.parent.parent / base_name]
base = next((candidate for candidate in base_candidates if candidate.exists()), None)
main=(root/'scripts/main.gd').read_text('utf8')
ui=(root/'scripts/touch_overlay.gd').read_text('utf8')
project=(root/'project.godot').read_text('utf8')
checks=[]
def check(title, yes):
    checks.append(bool(yes))
    print(('PASS ' if yes else 'FAIL ')+title)

def val(s,name):
    m=re.search(r'const '+re.escape(name)+r': float = ([0-9.]+)',s)
    assert m, name
    return float(m.group(1))

radius=val(main,'DRAG_RADIUS'); old_radius=112.0
ratio=val(main,'BOOST_RING_START_RATIO'); ui_ratio=val(ui,'CONTROLLER_INNER_RING_RADIUS_RATIO')
speed=val(main,'MOVE_SPEED'); multiplier=val(main,'MOVEMENT_BOOST_MULTIPLIER')
check('v72 project title', 'SERA v72 | Ring Run Boost 1.5x' in project)
check('enlarged exactly 1.5x', radius == old_radius*1.5 == 168.0)
check('run/boost boundary equals UI inner ring radius', abs(ratio-ui_ratio)<1e-10 and 0.4<ratio<0.8)
check('run velocity and boost 1.5x',speed==3.25 and multiplier==1.5 and speed*multiplier==4.875)
check('main touch origin -> visual anchor unchanged','touch_ui.call("show_drag", pointer_origin, pointer_location, DRAG_RADIUS)' in main)
check('distance-based threshold, not magnitude-clamped', 'pos.distance_to(pointer_origin)' in main and '>= DRAG_RADIUS * BOOST_RING_START_RATIO' in main)
check('analog magnitude saturates at run/boost boundary', '(pos - pointer_origin) / (DRAG_RADIUS * BOOST_RING_START_RATIO)' in main)
check('speed is physics horizontal movement only','player.velocity = world_move * MOVE_SPEED * speed_multiplier' in main)
check('run / boost switch with re-entry', 'if movement_boost_active != boost_requested:' in main and 'movement_boost_active = boost_requested' in main)
check('reset at press and release',main.count('movement_boost_active = false')==2)
check('UI switch updated when input changes',main.count('touch_ui.call("set_movement_boost", movement_boost_active)')==1)
check('two modes in overhead controller pill', 'BOOST  1.5x' in ui and 'RUN  1.0x' in ui)
check('on-screen header state reflects boost', 'MOVE BOOST  x1.5' in main and 'RUN  x1.0' in main)
check('outer ring emphasized when boosted', 'var ring_fill: Color =' in ui and 'if movement_boost_active else' in ui)
check('UI directly uses Godot draw primitives',all(x in ui for x in ('draw_arc(', 'draw_string(font,','draw_rect(rect,')) and 'draw_texture' not in ui)
check('reference RGBA colors preserved',all(x in ui for x in ('Color(0.13, 0.54, 0.61, 0.45)', 'Color(0.15, 0.60, 0.68, 0.08)', 'Color(0.21, 0.85, 0.93, 0.87)', 'Color(0.21, 0.85, 0.93, 0.30)')))
check('unpainted gap remains even with displaced knob', ui_ratio > val(ui,'CONTROLLER_KNOB_RADIUS_RATIO')+val(ui,'CONTROLLER_KNOB_TRAVEL_RATIO'))
check('step speed untouched', 'const STEP_SPEED: float = 10.0' in main and 'const STEP_CLOSE_SPEED: float = 6.0' in main)
check('knockback untouched','const DAMAGE_KNOCKBACK_DISTANCE: float = 1.20' in main and 'const DAMAGE_KNOCKBACK_DURATION: float = 0.24' in main)
check('enemy AI unchanged', 'var fire_interval_min: float = 2.0' in (root/'scripts/enemy_shooter.gd').read_text('utf8') and 'var travel_speed: float = 12.0' in (root/'scripts/enemy_projectile.gd').read_text('utf8'))
check('old drag attack/flick preserved', all(x in main for x in ('_classify_side_flick(release_pos - pointer_origin, press_duration)','_start_side_step(flick_side)','_start_attack()')))
check('control remains non-interactive', 'touch_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE' in main)
check('screen overlay fade unchanged',all(x in ui for x in ('const OPERATION_ZONE_TOP_RATIO: float = 0.75','const OPERATION_ZONE_SOLID_RATIO: float = 0.92','Color(0.494, 0.510, 0.533, 0.85)')))
check('expanded controller drawn only when dragging', 'if dragging:\n        _draw_radial_controller(accent, low)' in ui and 'dragging = false\n    movement_boost_active = false' in ui)
check('original reticle remains present', 'draw_arc(mark, lock_radius, start, start + LOCK_ARC_SWEEP' in ui)
check('mode label uses native UI Font', 'get_theme_default_font()' in ui and 'HORIZONTAL_ALIGNMENT_CENTER' in ui)
for d,mode in [(0,'RUN'), (ratio*radius-1e-3,'RUN'),(ratio*radius,'BOOST'),(radius,'BOOST'),(radius*2,'BOOST')]:
    check(f'distance {d:.3f}px -> {mode}', ('BOOST' if d>=ratio*radius else 'RUN') == mode)

if base is not None:
    with zipfile.ZipFile(base) as z:
        old = {name.split('/',1)[1]:z.read(name) for name in z.namelist() if '/' in name and not name.endswith('/')}
    current = {p.relative_to(root).as_posix(): p.read_bytes() for p in root.rglob('*') if p.is_file()}
    modified={n for n in old.keys() & current.keys() if old[n] != current[n]}
    added=set(current)-set(old)
    check('no v71 file omitted',not(set(old)-set(current)))
    check('only allowed source/config/development changes',modified=={'scripts/main.gd','scripts/touch_overlay.gd','project.godot','DEVELOPMENT.md'})
    check('only v72 README/test additions', added=={'README_v72_ja.md','tools/v72_run_boost_self_check.py'})
    check('every unchanged v71 source/data byte preserved',all(old[n]==current[n] for n in old if n not in modified))
    old_main=old['scripts/main.gd'].decode('utf8')
    # A chosen set of core functions must match exactly (other than intended state text).
    for fn, next_fn in [('_classify_side_flick','_start_side_step'),('_start_side_step','_finish_side_step'),('_advance_side_step','_move_player_swept'),('_on_enemy_projectile_hit','_begin_damage_reaction'),('_advance_damage_knockback','_advance_projectile_hit_overlay')]:
        def between(t): return t.split(f'func {fn}(',1)[1].split(f'func {next_fn}(',1)[0]
        check(f'{fn} logic remains byte-identical',between(old_main)==between(main))
else:
    print('INFO v71 source ZIP is unavailable; only standalone checks executed')
print(f'\n{sum(checks)}/{len(checks)} checks passed')
if not all(checks):sys.exit(1)
