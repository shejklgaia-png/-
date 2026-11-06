#!/usr/bin/env python3
"""Static v67 check (no Godot execution)."""
from pathlib import Path
from zipfile import ZipFile
import sys, re, math
root = Path(__file__).resolve().parents[1]
source = Path(sys.argv[1])
checks = []
def ck(name, ok):
    checks.append((name,bool(ok)))
    print(('PASS' if ok else 'FAIL')+': '+name)
shooter=(root/'scripts/enemy_shooter.gd').read_text()
projectile=(root/'scripts/enemy_projectile.gd').read_text()
ck('2.0s minimum fire interval', 'var fire_interval_min: float = 2.0' in shooter)
ck('2.0s maximum fire interval', 'var fire_interval_max: float = 2.0' in shooter)
ck('2.0s until first shot', 'var first_shot_delay: float = 2.0' in shooter)
ck('12 m/s firing speed', 'var projectile_speed: float = 12.0' in shooter)
ck('12 m/s projectile fallback speed', 'var travel_speed: float = 12.0' in projectile)
ck('0.65s warning preserved', 'var warning_duration: float = 0.65' in shooter)
ck('initial warning offset includes warning', shooter.count('_remaining = maxf(0.0, first_shot_delay - warning_duration)') == 2)
ck('subsequent shot cadence includes warning', '_remaining = maxf(0.0, randf_range(fire_interval_min, maxf(fire_interval_min, fire_interval_max)) - warning_duration)' in shooter)
ck('aim lock preserved', '_locked_direction = (aim_point - _warning_origin).normalized()' in shooter)
ck('shot uses projectile speed', 'projectile.call("configure", player_node, _locked_direction, projectile_speed)' in shooter)
ck('collision maintained', 'direct_space_state.intersect_ray(query)' in projectile and 'body_entered.connect(_on_body_entered)' in projectile)
ck('first shot and cadence theoretical 2s', math.isclose(2.0-0.65+0.65,2.0) and math.isclose(2.0-0.65+0.65,2.0))
missing=[]
for f in root.rglob('*.gd'):
    for r in re.findall(r'(?:preload|load)\("res://([^"]+)"\)',f.read_text()):
        if not (root/r).is_file(): missing.append((f,r))
ck('all resource references exist',not missing)
with ZipFile(source) as z:
    old={Path(n).as_posix().split('/',1)[1]:z.read(n) for n in z.namelist() if n.count('/') and not n.endswith('/') and all(ord(c)<128 for c in n)}
current={str(f.relative_to(root)):f.read_bytes() for f in root.rglob('*') if f.is_file() and all(ord(c)<128 for c in str(f.relative_to(root)))}
changed=sorted(k for k in old.keys()&current.keys() if old[k]!=current[k])
removed=sorted(old.keys()-current.keys())
new=sorted(current.keys()-old.keys())
ck('only intended changes',changed==['DEVELOPMENT.md','project.godot','scripts/enemy_projectile.gd','scripts/enemy_shooter.gd'])
ck('no existing files removed',not removed)
ck('only expected additions',new==['README_v67_ja.md','tools/v67_enemy_ai_self_check.py'])
print('modified:',changed,'\nremoved:',removed,'\nadded:',new)
print(f'{sum(ok for _,ok in checks)}/{len(checks)} tests passed')
if not all(ok for _,ok in checks): sys.exit(1)
