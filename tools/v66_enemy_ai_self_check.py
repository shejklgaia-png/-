#!/usr/bin/env python3
"""Static regression check for SERA v66 (does not run the Godot engine)."""
from pathlib import Path
import math
import re
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BASE = Path(sys.argv[1]) if len(sys.argv) > 1 else None
checks = []

def check(name, condition):
    checks.append((name, bool(condition)))
    print(f'{"PASS" if condition else "FAIL"}: {name}')

main = (ROOT / 'scripts/main.gd').read_text()
ai = (ROOT / 'scripts/enemy_shooter.gd').read_text()
bullet = (ROOT / 'scripts/enemy_projectile.gd').read_text()
ui = (ROOT / 'scripts/touch_overlay.gd').read_text()

# All resource links must target files that exist in the ZIP.
missing_resources = []
for path in ROOT.rglob('*.gd'):
    for ref in re.findall(r'\b(?:preload|load)\("(res://[^\"]+)"\)', path.read_text()):
        if not (ROOT / ref[len('res://'):]).is_file():
            missing_resources.append((str(path.relative_to(ROOT)), ref))
check('resource references', not missing_resources)
if missing_resources:
    print(missing_resources)

for title, content in [('main', main), ('enemy_shooter', ai), ('enemy_projectile', bullet)]:
    funcs = re.findall(r'^func\s+([\w_]+)\s*\(', content, flags=re.M)
    check(f'{title} unique functions', len(funcs) == len(set(funcs)))
    check(f'{title} spaces-only indentation', all(not l.startswith('\t') for l in content.splitlines()))

check('main instantiates shooter exactly once', main.count('_build_enemy_shooter()') == 2)
check('main preserves existing input and movement', all(
    v in main for v in ('func _classify_side_flick', 'func _advance_side_step',
                      'func _start_attack', 'func _advance_attack',
                      'func _screen_drag_to_ground', 'func _fit_full_frame')))
check('shooter has timed windup and cooldown', all(
    v in ai for v in ('first_shot_delay', 'warning_duration', 'FirePhase.WARNING',
                    'fire_interval_min', 'fire_interval_max', 'randf_range')))
check('aim snapshots before shot; nonhoming',
      '_locked_direction = (aim_point - _warning_origin).normalized()' in ai and
      '_fire_projectile()' in ai and 'projectile.call("configure", player_node, _locked_direction, projectile_speed)' in ai)
check('target down disables new shooting', 'target_hp > 0' in main and 'if not can_fire:' in ai)
check('bullet collision two paths', all(v in bullet for v in (
    'body_entered.connect', 'direct_space_state.intersect_ray',
    'if _hit_reported:', '_report_hit(', 'collision_mask = PLAYER_LAYER')))
check('player hp and shield are not silently introduced',
      'player_hp' not in main and 'player_hp' not in ai and 'player_hp' not in bullet)
check('hit tint ignores all input',
      'projectile_hit_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE' in main)
check('v65 gray operation area preserved', '#7E8288' in (ROOT / 'README_v65_ja.md').read_text()
      and 'func _draw()' in ui)

# Corner/cardinal shot origin should always be outside cube's XZ footprint.
all_outside = True
min_clearance = 1000.0
for k in range(720):
    angle = (k / 720) * math.tau
    dx, dz = math.cos(angle), math.sin(angle)
    dist = 1.0 / max(abs(dx), abs(dz))
    x, z = dx * (dist + 0.30), dz * (dist + 0.30)
    clearance = max(abs(x), abs(z)) - 1.0
    min_clearance = min(min_clearance, clearance)
    all_outside &= clearance > 0.2
check('muzzle starts outside target on all bearings', all_outside)
print(f'minimum AABB clearance in sampled bearings: {min_clearance:.3f} m')

if BASE and BASE.exists():
    with zipfile.ZipFile(BASE) as old:
        # The archive contains a root folder. Compare file contents by trailing relative path.
        old_content = {}
        for name in old.namelist():
            parts = Path(name).parts
            if len(parts) > 1 and not name.endswith('/'):
                # Some original ZIP entries carry UTF-8 bytes without the UTF-8
                # filename flag; Python's zipfile shows them as CP437 glyphs.
                # Info-ZIP extracted the intended Japanese UTF-8 names.
                rel_name = '/'.join(parts[1:])
                if any(ord(ch) > 127 for ch in rel_name):
                    try:
                        rel_name = rel_name.encode('cp437').decode('utf-8')
                    except (UnicodeEncodeError, UnicodeDecodeError):
                        pass
                old_content[rel_name] = old.read(name)
    current_content = {str(f.relative_to(ROOT)): f.read_bytes() for f in ROOT.rglob('*') if f.is_file()}
    modified = sorted(k for k in old_content.keys() & current_content.keys() if old_content[k] != current_content[k])
    removed = sorted(old_content.keys() - current_content.keys())
    added = sorted(current_content.keys() - old_content.keys())
    print('modified:', modified)
    print('removed:', removed)
    print('added:', added)
    check('original modified files restricted', modified == ['project.godot', 'scripts/main.gd'])
    check('original files not removed', not removed)
    check('only intended files added', set(added) == {
        'DEVELOPMENT.md', 'README_v66_ja.md', 'scripts/enemy_shooter.gd',
        'scripts/enemy_projectile.gd', 'tools/v66_enemy_ai_self_check.py'
    })

print(f'{sum(ok for _, ok in checks)}/{len(checks)} checks passed')
if not all(ok for _, ok in checks):
    sys.exit(1)
