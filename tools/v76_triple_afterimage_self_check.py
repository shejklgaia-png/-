#!/usr/bin/env python3
from pathlib import Path
import zipfile, sys
root = Path(__file__).resolve().parents[1]
main = (root/"scripts/main.gd").read_text("utf8")
rig = (root/"scripts/sera_rig.gd").read_text("utf8")
project = (root/"project.godot").read_text("utf8")
ghost = (root/"shaders/sera_motion_ghost.gdshader").read_text("utf8")
checks=[]
def ck(label, condition):
    checks.append((label, bool(condition)))
    print(("PASS" if condition else "FAIL") + " " + label)
ck("v76 project naming and renderer retained", 'SERA v76 | Triple Afterimage Motion Blur' in project and 'renderer/rendering_method="gl_compatibility"' in project)
ck("run and boost values unchanged", all(x in main for x in ('const MOVE_SPEED: float = 3.25','const MOVEMENT_BOOST_MULTIPLIER: float = 1.5','const DRAG_RADIUS: float = 168.0','BOOST_OUTSIDE_RADIUS_RATIO: float = 1.0')))
ck("step speeds preserved", all(x in main for x in ('const STEP_SPEED: float = 10.0','const STEP_CLOSE_SPEED: float = 8.0','const STEP_MIN_ARC_LENGTH: float = 2.0','const STEP_MAX_ARC_LENGTH: float = 4.0','const STEP_MAX_DURATION: float = 0.40')))
ck("enemy cadence preserved", 'var fire_interval_min: float = 2.0' in (root/'scripts/enemy_shooter.gd').read_text() and 'var travel_speed: float = 12.0' in (root/'scripts/enemy_projectile.gd').read_text())
ck("damage knockback preserved", all(x in main for x in ('const DAMAGE_KNOCKBACK_DISTANCE: float = 1.20','const DAMAGE_KNOCKBACK_DURATION: float = 0.24')))
ck("blur still gated to step and boost only", 'blur_step_this_physics_frame or (combat_state == CombatState.IDLE' in main and 'and movement_boost_active and running' in main)
ck("background blur removed", 'far_blur' not in main and 'MOTION_BLUR_FAR_START' not in main and 'MOTION_BLUR_FAR_FULL' not in main)
ck("triple afterimage arrays present", 'var distance_factors: Array = [0.34, 0.68, 1.0]' in main and 'var alpha_values: Array = [0.28, 0.18, 0.10] if blur_step_this_physics_frame else [0.22, 0.14, 0.08]' in main)
ck("rig accepts arrays for afterimages", 'func set_motion_blur(enabled: bool, offsets_world: Array, alphas: Array) -> void:' in rig)
ck("rig creates 3 ghost layers", 'const MOTION_GHOST_LAYERS: int = 3' in rig and '_add_motion_blur_copies(piece, parent)' in rig)
ck("ghost meshes use authored palette shader", 'ghost.material_override = _motion_blur_mats[layer_index]' in rig and 'texture(sera_palette, UV)' in ghost)
ck("slash foreground path preserved", 'part.material_overlay = overlay' in rig and 'if _foreground_enabled:' in rig)
ck("off state disables motion blur", 'rig.call("set_motion_blur", false, [], [])' in main)
base_archive = root.parent/'sera_portrait_godot_melee_v75_selective_motion_blur.zip'
if base_archive.is_file():
    with zipfile.ZipFile(base_archive) as z:
        base = {n.split('/',1)[1]:z.read(n) for n in z.namelist() if '/' in n and not n.endswith('/')}
    cur = {f.relative_to(root).as_posix():f.read_bytes() for f in root.rglob('*') if f.is_file()}
    changed = {n for n in base.keys() & cur.keys() if base[n] != cur[n]}
    added = set(cur) - set(base)
    ck('v75 original files all present', not(set(base)-set(cur)))
    ck('only intended originals changed', changed == {'scripts/main.gd','scripts/sera_rig.gd','project.godot','DEVELOPMENT.md'})
    ck('only planned v76 additions', added == {'README_v76_ja.md','tools/v76_triple_afterimage_self_check.py'})
    ck('other scripts untouched', all(base[n]==cur[n] for n in base if n.startswith('scripts/') and n not in changed))
print(f"{sum(ok for _, ok in checks)}/{len(checks)} PASS")
sys.exit(0 if all(ok for _, ok in checks) else 1)
