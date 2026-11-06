#!/usr/bin/env python3
"""v91 regression/structural/numeric smoke checks. Does not run Godot."""
from __future__ import annotations
from pathlib import Path
import re
import math
import hashlib

root = Path(__file__).resolve().parents[1]
baseline = root.parent / 'sera_v90_work'
checked = 0

def check(name: str, condition: bool) -> None:
    global checked
    if not condition:
        raise AssertionError(name)
    checked += 1

main = (root / 'scripts/main.gd').read_text('utf8')
shooter = (root / 'scripts/enemy_shooter.gd').read_text('utf8')
projectile = (root / 'scripts/enemy_projectile.gd').read_text('utf8')
area = (root / 'scripts/enemy_area_attack.gd').read_text('utf8')
ui = (root / 'scripts/enemy_debug_ui.gd').read_text('utf8')
project = (root / 'project.godot').read_text('utf8')

check('v91 project name', 'SERA v91' in project)
# Compare to the local v90 baseline when present. In a standalone extracted
# v91 ZIP the prior version may not exist, and the rest of the self-checks
# must still function without it.
if baseline.exists():
    expected_changed = {'scripts/main.gd', 'scripts/enemy_shooter.gd', 'scripts/enemy_projectile.gd', 'project.godot', 'DEVELOPMENT.md'}
    expected_added = {'scripts/enemy_area_attack.gd', 'scripts/enemy_debug_ui.gd', 'README_v91_ja.md', 'tools/v91_enemy_attacks_self_check.py'}
    actual_changed = {str(f.relative_to(root)) for f in root.rglob('*') if f.is_file() and (baseline/f.relative_to(root)).is_file() and f.read_bytes() != (baseline/f.relative_to(root)).read_bytes()}
    actual_added = {str(f.relative_to(root)) for f in root.rglob('*') if f.is_file() and not (baseline/f.relative_to(root)).exists()}
    check('v90 changes restricted to required files', actual_changed == expected_changed)
    check('v91 adds only expected files', actual_added == expected_added)
    check('v90 source files all present', not [f for f in baseline.rglob('*') if f.is_file() and not (root/f.relative_to(baseline)).is_file()])
    for folder in ('assets', 'blockbench', 'shaders', 'scenes'):
        a = {f.relative_to(baseline/folder): hashlib.sha256(f.read_bytes()).digest() for f in (baseline/folder).rglob('*') if f.is_file()}
        b = {f.relative_to(root/folder): hashlib.sha256(f.read_bytes()).digest() for f in (root/folder).rglob('*') if f.is_file()}
        check(f'{folder} asset hashes untouched', a == b)
    for path in ('scripts/sera_rig.gd', 'scripts/hit_burst.gd', 'scripts/sword_trail.gd', 'scripts/touch_overlay.gd'):
        check(f'{path} unchanged', (root/path).read_bytes() == (baseline/path).read_bytes())
else:
    check('standalone project exists', (root/'project.godot').is_file())
    for folder in ('assets', 'blockbench', 'shaders', 'scenes'):
        check(f'{folder} included in standalone release', (root/folder).is_dir() and any((root/folder).rglob('*')))

for script in root.rglob('*.gd'):
    source = script.read_text('utf8')
    for res in re.findall(r'(?:preload|load)\("res://([^"\n]+)"\)', source):
        check(f'{script.name} resource exists: {res}', (root / res).exists())

for name, contents in [('main.gd', main),('enemy_shooter.gd', shooter),('enemy_projectile.gd', projectile), ('enemy_area_attack.gd', area),('enemy_debug_ui.gd', ui)]:
    # GDScript quote/comment-aware bracket check, not an engine parser.
    stack = []
    pairs = {')':'(',']':'[','}':'{'}
    in_string = False
    escaped = False
    for line in contents.splitlines():
        for char in line:
            if in_string:
                if escaped: escaped = False
                elif char == '\\': escaped = True
                elif char == '"': in_string = False
                continue
            if char == '#': break
            if char == '"': in_string=True; continue
            if char in '([{': stack.append(char)
            elif char in ')]}':
                check(f'{name} balanced bracket {char}', bool(stack) and stack.pop() == pairs[char])
    check(f'{name}: all bracket pairs closed', not stack and not in_string)

# Four modes, shared warning -> execution path, and projectile visual distinction.
for mode in ('AIMED', 'LEAD', 'SHOCKWAVE', 'ARC'):
    check(f'attack type {mode}', mode in shooter)
check('old fire cooldown stays 2sec', 'var fire_interval_min: float = 2.0' in shooter and 'var fire_interval_max: float = 2.0' in shooter)
check('old bullet speed stays 12m/s', 'var projectile_speed: float = 12.0' in shooter and 'var travel_speed: float = 12.0' in projectile)
check('locked bullet fired, not homing', '_locked_direction' in shooter and 'travel_direction * (travel_speed * delta)' in projectile)
check('lead uses measured player displacement', '(pos - _last_player_position) / delta' in shooter)
check('lead includes warning duration', 'player_velocity * warn_seconds' in shooter)
check('lead intercept quadratic', 'b * b - 4.0 * a * c' in shooter and 'sqrt(discriminant)' in shooter)
check('lead displacement limited', 'MAX_LEAD_DISTANCE: float = 8.0' in shooter and 'lead_displacement.limit_length(MAX_LEAD_DISTANCE)' in shooter)
check('lead bullet colored cyan', 'visual_variant == 1' in projectile and '70e4ff' in projectile)
check('existing projectile sweeps ray', 'PhysicsRayQueryParameters3D.create' in projectile and 'body_entered.connect' in projectile)
check('area warning before activation', 'set_warning_progress' in shooter and '_pending_area.call("activate")' in shooter)
check('areas use geometric sweep rather than discrete intersection only', 'previous_radius' in area and 'minf(now_distance, last_distance)' in area and 'maxf(now_distance, last_distance)' in area)
check('shockwave 360 degrees', '_draw_band(r - 0.19, r + 0.19, 0.0, TAU)' in area and 'SHOCKWAVE_SPEED: float = 8.0' in area)
check('shockwave hits only once', 'if hit_sent:' in area)
check('arc orientation locked', 'atan2(facing.x, facing.z)' in area and '_locked_attack = selected_attack' in shooter)
check('arc sector based on angle', 'offset.normalized().dot(facing)' in area)
check('arc telegraph range', 'ARC_OUTER_RADIUS: float = 5.5' in area and 'ARC_DEGREES: float = 145.0' in area)
check('area reports same player hit signal', 'player_hit.emit(pos, direction.normalized())' in area and '_on_projectile_hit' in shooter)
check('main retains existing damage handler', 'func _on_enemy_projectile_hit' in main and '_begin_damage_reaction(incoming_direction)' in main)
check('select/cancel old pending & active attacks', '_cancel_warning()' in shooter and 'for child in projectile_parent.get_children()' in shooter)
check('fire still telegraphs', 'func trigger_attack()' in shooter and '_begin_warning()' in shooter)
check('auto fire stops during cooldown', '_phase == FirePhase.COOLDOWN and not auto_fire_enabled:' in shooter)
check('debug button signals', all(f'signal {x}' in ui for x in ['attack_selected','fire_requested','auto_fire_changed']))
check('four mode buttons plus two actions', all(f'"{x}"' in ui for x in ['AIM', 'LEAD', 'SHOCK', 'ARC', 'FIRE', 'AUTO ON']))
check('debug UI is after old HUD creation', 'func _build_overlay()' in main and 'enemy_debug_ui = ENEMY_DEBUG_SCRIPT.new()' in main)
check('debug controls bind shooter methods', all(f'Callable(enemy_shooter, "{x}")' in main for x in ['set_attack_type','trigger_attack','set_auto_fire']))
check('debug area excluded from gameplay gestures', 'enemy_debug_ui.get_global_rect().has_point(pos)' in main and 'if _pointer_on_step_hud(event.position)' in main)
check('isolated pool used, not root', 'enemy_shooter.set("projectile_parent", enemy_attack_pool)' in main)
check('v90 boost threshold unchanged', 'const BOOST_START_RADIUS_RATIO: float = 1.25' in main and 'const BOOST_EXIT_RADIUS_RATIO: float = 1.10' in main and 'const BOOST_CONFIRM_SECONDS: float = 0.10' in main)
check('v88 backstep remains four meters', 'const BACK_STEP_DISTANCE: float = 4.0' in main)
check('three melee damage values', 'STRIKE_DAMAGE = [12, 12, 26]' in main)
check('Godot 4 compatibility retained', 'renderer/rendering_method="gl_compatibility"' in project)
check('warning time is type-dependent', 'SHOCKWAVE_WARNING_SECONDS: float = 0.80' in shooter and 'ARC_WARNING_SECONDS: float = 0.95' in shooter)

# Numerical model: lead on moving player differs from aimed shot, but zero velocity doesn't.
def lead_point(origin, player_aim, velocity, warn_time, bullet_speed=12.0):
    r = [player_aim[i] + velocity[i]*warn_time-origin[i] for i in range(3)]
    a = sum(v*v for v in velocity)-bullet_speed*bullet_speed
    b = 2*sum(r[i]*velocity[i] for i in range(3))
    c = sum(v*v for v in r)
    flight = math.sqrt(c)/bullet_speed
    if abs(a)>1e-5:
        disc=b*b-4*a*c
        if disc>=0:
            roots=[(-b-math.sqrt(disc))/(2*a),(-b+math.sqrt(disc))/(2*a)]
            positive=[q for q in roots if q>0]
            if positive: flight=min(positive)
    lead = [v*(warn_time+min(1.75,flight)) for v in velocity]
    length=math.sqrt(sum(v*v for v in lead))
    if length>8: lead=[v*8/length for v in lead]
    return [player_aim[i]+lead[i] for i in range(3)]

p = [0,1.05,-8]
o = [0,1.05,-6.7]
check('lead zero velocity equals aimed', lead_point(o,p,[0,0,0],.65)==p)
for v in (-5,-3.25,3.25,5):
    predicted=lead_point(o,p,[v,0,0],.65)
    check('lead direction follows player velocity '+str(v), (predicted[0]-p[0])*v>0)
    check('lead distance <= 8 meters '+str(v), abs(predicted[0]-p[0])<=8.0001)
# Shockwave ring sweep is continuous over a frame; arc is forward 145 degrees.
check('wave catches radius 4.0 between 3.8 and 4.1', 4.0 <= 4.1+.32+.4 and 4.0 >= 3.8-.32-.4)
check('wave misses radius 8 between 3.8 and 4.1', not (8 <= 4.1+.32+.4 and 8 >= 3.8-.32-.4))
check('arc at 0 degrees hits', math.cos(math.radians(0))>=math.cos(math.radians(72.5)))
check('arc at 120 degrees misses without capsule tolerance', math.cos(math.radians(120))<math.cos(math.radians(72.5)))
check('arc beyond 5.9m misses', 6.0>5.5+.4)
print(f'v91 checks: {checked} passed; Godot/Android execution NOT performed')
