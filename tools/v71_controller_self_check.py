#!/usr/bin/env python3
"""v71 static checks; checks code and archive integrity but does NOT run Godot."""
from pathlib import Path
import hashlib
import re
import sys
import zipfile

root = Path(__file__).resolve().parents[1]
base_zip = root.parents[1] / 'sera_portrait_godot_melee_v70_damage_knockback_1_2m.zip'

checks = []
def verify(label, result):
    checks.append(bool(result))
    print(('PASS' if result else 'FAIL') + ' ' + label)

ui = (root / 'scripts/touch_overlay.gd').read_text(encoding='utf-8')
main = (root / 'scripts/main.gd').read_text(encoding='utf-8')
project = (root / 'project.godot').read_text(encoding='utf-8')
verify('project is v71', 'SERA v71 | Vector Touch Controller' in project)
verify('drawing stays native CanvasItem', 'extends Control' in ui and 'func _draw_radial_controller(' in ui)
verify('no external controller texture', 'Texture2D' not in ui and 'draw_texture' not in ui and 'load(' not in ui)
verify('uses existing touch API', all(f'func {n}(' in ui for n in ('show_drag','hide_drag','set_target_marker_projection','set_melee_in_range')))
verify('draw on drag, hidden otherwise', 'if dragging:\n        _draw_radial_controller(accent, low)' in ui and 'dragging = false\n    queue_redraw()' in ui)
verify('wide ring, empty annular gap', 'draw_arc(anchor_point, ring_middle, 0.0, TAU, 96,' in ui and 'draw_circle(anchor_point, outer_radius' not in ui)
verify('inner disc drawn separately', 'draw_circle(knob_center, knob_radius, Color(0.13, 0.54, 0.61, 0.45))' in ui)
verify('outer double arrow, center single arrow',ui.count('_draw_chevron(anchor_point, direction')==2 and ui.count('_draw_chevron(knob_center, direction')==1)
verify('only four primary directions', 'Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT' in ui)
verify('antialiased vector strokes and round ends', 'draw_polyline(PackedVector2Array([first, outward_tip, last]), tint, stroke, true)' in ui and 'draw_circle(outward_tip, stroke * 0.5, tint)' in ui)
verify('original opacity and color values',all(t in ui for t in ('Color(0.15, 0.60, 0.68, 0.08)', 'Color(0.13, 0.54, 0.61, 0.45)', 'Color(0.21, 0.85, 0.93, 0.87)', 'Color(0.21, 0.85, 0.93, 0.30)')))
verify('v70 operation zone retained',all(t in ui for t in ('OPERATION_ZONE_TOP_RATIO: float = 0.75', 'OPERATION_ZONE_SOLID_RATIO: float = 0.92', 'Color(0.494, 0.510, 0.533, 0.85)', 'draw_polygon(fade_vertices, fade_colors)')))
verify('target reticle independent',all(t in ui for t in ('func set_target_marker_projection(', 'func set_melee_in_range(', 'draw_arc(mark, lock_radius, start, start + LOCK_ARC_SWEEP')))
verify('original movement radius and input APIs preserved',all(t in main for t in ('const DRAG_RADIUS: float = 112.0','touch_ui.call("show_drag", pointer_origin, pointer_location, DRAG_RADIUS)', 'touch_ui.call("hide_drag")','var delta: Vector2 = (pos - pointer_origin) / DRAG_RADIUS')))
verify('v70 knockback parameters unchanged', 'DAMAGE_KNOCKBACK_DISTANCE: float = 1.20' in main and 'DAMAGE_KNOCKBACK_DURATION: float = 0.24' in main)
verify('v67 shooter unchanged', 'var fire_interval_min: float = 2.0' in (root/'scripts/enemy_shooter.gd').read_text() and 'var travel_speed: float = 12.0' in (root/'scripts/enemy_projectile.gd').read_text())
visual_gap = 0.62 - (0.375 + 0.115)
verify('transparent separation remains at max drag',visual_gap > 0.10)
verify('documentation present',all((root/x).exists() for x in ['DEVELOPMENT.md','README_v71_ja.md']))

if base_zip.exists():
    with zipfile.ZipFile(base_zip) as z:
        originals = {name.split('/',1)[1]: z.read(name) for name in z.namelist() if '/' in name and not name.endswith('/')}
    current = {p.relative_to(root).as_posix(): p.read_bytes() for p in root.rglob('*') if p.is_file()}
    modified = {n for n in originals.keys() & current.keys() if originals[n] != current[n]}
    added = set(current) - set(originals)
    verify('no v70 files removed',not(set(originals) - set(current)))
    verify('only intended original files changed',modified=={'scripts/touch_overlay.gd', 'project.godot', 'DEVELOPMENT.md'})
    verify('only v71 doc/check files added', added=={'README_v71_ja.md','tools/v71_controller_self_check.py'})
    old_ui = originals['scripts/touch_overlay.gd'].decode('utf-8')
    verify('original _draw gradient/target section bit-for-bit',old_ui.split('func _draw() -> void:',1)[1].split('    if dragging:',1)[0]==ui.split('func _draw() -> void:',1)[1].split('    if dragging:',1)[0])
    verify('original drag/input handlers unchanged',old_ui.split('func _ready()',1)[1].split('func _draw() -> void:',1)[0]==ui.split('func _ready()',1)[1].split('func _draw() -> void:',1)[0])
else:
    print('WARNING: base ZIP absent; baseline byte checks skipped')

ok = sum(checks)
print(f'\n{ok}/{len(checks)} v71 static checks passed')
if ok != len(checks):
    sys.exit(1)
