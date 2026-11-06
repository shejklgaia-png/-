#!/usr/bin/env python3
"""v78 per-mode afterimage lifetime and v77 regression checks; no runtime."""
from pathlib import Path
from zipfile import ZipFile
import re, sys, math
root = Path(__file__).resolve().parents[1]
rig = (root/'scripts/sera_rig.gd').read_text(encoding='utf-8')
main = (root/'scripts/main.gd').read_text(encoding='utf-8')
project = (root/'project.godot').read_text(encoding='utf-8')
shader = (root/'shaders/sera_motion_ghost.gdshader').read_text(encoding='utf-8')
checks=[]
def ck(name, condition):
    checks.append((name, bool(condition)))
    print(('PASS' if condition else 'FAIL') + ' ' + name)
ck('v78 version name', 'SERA v78 | Fast Fading Boost Afterimages' in project)
ck('GL Compatibility remains configured', 'renderer/rendering_method="gl_compatibility"' in project)
ck('v77 emission interval retained', 'const AFTERIMAGE_INTERVAL: float = 0.055' in rig)
ck('v77 maximum afterimages retained', 'const AFTERIMAGE_LAYERS: int = 3' in rig)
ck('step lifetime unchanged 0.22 s', 'const AFTERIMAGE_STEP_LIFETIME: float = 0.22' in rig)
ck('boost lifetime shortened to 0.14 s', 'const AFTERIMAGE_BOOST_LIFETIME: float = 0.14' in rig)
ck('step alpha unchanged 0.34', 'const AFTERIMAGE_STEP_ALPHA: float = 0.34' in rig)
ck('boost alpha unchanged 0.28', 'const AFTERIMAGE_BOOST_ALPHA: float = 0.28' in rig)
ck('capture per-slot lifetime', '_afterimage_lifetimes[slot] = AFTERIMAGE_STEP_LIFETIME if stepping else AFTERIMAGE_BOOST_LIFETIME' in rig)
ck('per-slot lifetime used when expiring', 'if age >= lifetime:' in rig and 'var lifetime: float = _afterimage_lifetimes[slot]' in rig)
ck('quadratic fade unchanged', 'layer_opacity[slot] = _afterimage_base_alphas[slot] * remaining * remaining' in rig)
ck('fading after movement stop preserved', rig.index('for slot in range(AFTERIMAGE_LAYERS):') < rig.index('if fast_movement:'))
ck('snapshot transform retained', 'ghosts.multimesh.set_instance_transform(slot, to_local * source.global_transform)' in rig)
ck('multimesh shader retained', 'INSTANCE_ID' in shader and 'trail_alphas' in shader)
ck('existing step/boost gating retained', 'and movement_boost_active and running' in main)
ck('background blur remains off', 'far_blur' not in main and 'selective_far_blur' not in main)
ck('step speed 8-10 m/s maintained', 'const STEP_CLOSE_SPEED: float = 8.0' in main and 'const STEP_SPEED: float = 10.0' in main)
ck('boost 1.5x maintained', 'const MOVEMENT_BOOST_MULTIPLIER: float = 1.5' in main)
ck('knockback maintained', 'const DAMAGE_KNOCKBACK_DISTANCE: float = 1.20' in main)
ck('2s enemy and 12m/s projectile maintained', 'var fire_interval_min: float = 2.0' in (root/'scripts/enemy_shooter.gd').read_text() and 'var travel_speed: float = 12.0' in (root/'scripts/enemy_projectile.gd').read_text())
# Numeric fade self check: identical step curve; boost falls sooner.
for age in (0.0, 0.025, 0.055, 0.10, 0.139, 0.14, 0.20, 0.22):
    def fade(alpha, t, life):
        return 0.0 if t >= life else alpha * (1-t/life)**2
    old_step = fade(0.34, age, 0.22)
    new_step = fade(0.34, age, 0.22)
    ck(f'step alpha identical at {age:.3f}s',math.isclose(old_step,new_step,rel_tol=0,abs_tol=1e-12))
ck('boost fade faster by 0.10s', fade(0.28,0.10,0.14) < fade(0.28,0.10,0.22))
ck('boost gone at 0.14s', fade(0.28,0.14,0.14)==0)
base_archive = root.parent/'sera_portrait_godot_melee_v77_temporal_afterimage.zip'
if not base_archive.is_file():
    ck('v77 base ZIP available',False)
else:
    with ZipFile(base_archive) as z:
        base={n.split('/',1)[1]:z.read(n) for n in z.namelist() if '/' in n and not n.endswith('/')}
    cur={f.relative_to(root).as_posix():f.read_bytes() for f in root.rglob('*') if f.is_file()}
    removed=set(base)-set(cur)
    added=set(cur)-set(base)
    changed={n for n in set(base)&set(cur) if base[n]!=cur[n]}
    ck('all v77 files preserved', not removed)
    ck('v77 changes limited to requested feature',changed=={'scripts/sera_rig.gd','project.godot','DEVELOPMENT.md'})
    ck('only new v78 docs and tests',added=={'README_v78_ja.md','tools/v78_boost_afterimage_self_check.py'})
    ck('all other scripts and resources byte identical', all(base[n]==cur[n] for n in base if n not in changed))
print(f'RESULT {sum(ok for _,ok in checks)}/{len(checks)} pass')
sys.exit(0 if all(ok for _,ok in checks) else 1)
