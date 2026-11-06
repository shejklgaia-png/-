#!/usr/bin/env python3
"""v77 temporal afterimage static/regression audit; Godot runtime not present."""
from pathlib import Path
from zipfile import ZipFile
import sys
root = Path(__file__).resolve().parents[1]
main = (root/'scripts/main.gd').read_text('utf8')
rig = (root/'scripts/sera_rig.gd').read_text('utf8')
shader = (root/'shaders/sera_motion_ghost.gdshader').read_text('utf8')
project = (root/'project.godot').read_text('utf8')
report = []
def check(name, ok):
    report.append((name,bool(ok)))
    print(('PASS' if ok else 'FAIL')+' '+name)
check('Project version and renderer', 'SERA v77 | Temporal Fading Afterimages' in project and 'renderer/rendering_method="gl_compatibility"' in project)
check('v76 controller and speeds preserved', all(x in main for x in ('const MOVE_SPEED: float = 3.25','const MOVEMENT_BOOST_MULTIPLIER: float = 1.5','const DRAG_RADIUS: float = 168.0','BOOST_OUTSIDE_RADIUS_RATIO: float = 1.0')))
check('Step minimum and maximum preserved', all(x in main for x in ('const STEP_CLOSE_SPEED: float = 8.0','const STEP_SPEED: float = 10.0','const STEP_MAX_DURATION: float = 0.40')))
check('Enemy cadence and projectile velocity preserved', 'var fire_interval_min: float = 2.0' in (root/'scripts/enemy_shooter.gd').read_text() and 'var travel_speed: float = 12.0' in (root/'scripts/enemy_projectile.gd').read_text())
check('Knockback distance preserved', 'const DAMAGE_KNOCKBACK_DISTANCE: float = 1.20' in main)
check('Motion active only during step or boost', 'blur_step_this_physics_frame or (combat_state == CombatState.IDLE' in main and 'and movement_boost_active and running' in main)
check('No background blur at runtime', 'far_blur' not in main and 'selective_far_blur' not in main)
check('Snapshot interval/lifetime/maximum', all(x in rig for x in ('const AFTERIMAGE_LAYERS: int = 3','const AFTERIMAGE_INTERVAL: float = 0.055','const AFTERIMAGE_LIFETIME: float = 0.22')))
check('Afterimage world root independent of Player', 'player_body.get_parent().add_child(_afterimage_root)' in rig and '_afterimage_root.name = "SeraTemporalAfterimages"' in rig)
check('Frozen pose and world-transform capture', 'to_local * source.global_transform' in rig and 'ghosts.multimesh.set_instance_transform(slot,' in rig)
check('No live-pose movement after snapshot', rig.count('set_instance_transform(')==1 and 'trail_world' not in rig and 'trail_world' not in shader)
check('MultiMesh uses exactly 3 instances per source mesh', 'batch.instance_count = AFTERIMAGE_LAYERS' in rig and 'batch.mesh = source.mesh' in rig and 'MultiMeshInstance3D.new()' in rig)
check('No skeleton duplication or CPU vertex edits', 'SurfaceTool' in rig and 'multimesh.set_instance' in rig and 'MeshDataTool.new()' not in rig and 'duplicate(' not in rig)
check('Alpha via shared shader and INSTANCE_ID', 'INSTANCE_ID' in shader and 'trail_alphas' in shader and '_afterimage_material.set_shader_parameter("trail_alphas", layer_opacity)' in rig)
check('Quadratic time fade', 'remaining * remaining' in rig and 'age / AFTERIMAGE_LIFETIME' in rig)
check('Only new captures during fast movement', 'if fast_movement:' in rig and '_emit_motion_afterimage(stepping)' in rig)
check('Fade continues after movement stop', rig.index('for slot in range(AFTERIMAGE_LAYERS):') < rig.index('if fast_movement:'))
check('One capture maximum each frame', 'if _afterimage_since_emit >= AFTERIMAGE_INTERVAL:' in rig and 'for' not in rig[rig.index('if _afterimage_since_emit >= AFTERIMAGE_INTERVAL:'):rig.index('_afterimage_was_moving = true')])
check('Three alpha layers per instance', 'layer_opacity[slot] = ' in rig and 'layer_opacity[emitted_slot] =' in rig)
check('Transparent ghosts and disabled cast shadows', 'blend_mix, depth_draw_never' in shader and 'SHADOW_CASTING_SETTING_OFF' in rig)
check('Stop state hides pool when fully faded', 'visible_instance_count = AFTERIMAGE_LAYERS if any_visible else 0' in rig)
check('Main updates temporal fade on hit-stop or normal frames', main.count('_update_motion_blur(delta)') == 2 and 'rig.call("update_motion_afterimages", delta, active, blur_step_this_physics_frame)' in main)
check('Authored animation untouched in v77', 'func _apply_animation(_delta: float)' in rig and 'RUN_ANIMATION_SPEED: float = 1.5' in rig)
base_path = root.parent/'sera_portrait_godot_melee_v76_player_triple_afterimage.zip'
if base_path.exists():
    with ZipFile(base_path) as z:
        base = {n.split('/',1)[1]:z.read(n) for n in z.namelist() if '/' in n and not n.endswith('/')}
    current={f.relative_to(root).as_posix():f.read_bytes() for f in root.rglob('*') if f.is_file()}
    changed={n for n in base.keys() & current.keys() if base[n] != current[n]}
    added=set(current)-set(base)
    check('v76 files retained',not(set(base)-set(current)))
    check('Only intended originals changed',changed=={'scripts/main.gd','scripts/sera_rig.gd','shaders/sera_motion_ghost.gdshader','project.godot','DEVELOPMENT.md'})
    check('Only planned files added', added=={'README_v77_ja.md','tools/v77_temporal_afterimage_self_check.py'})
    check('All original model, textures, animation data retained',all(base[n]==current[n] for n in base if n.startswith(('assets/','blockbench/'))))
    check('Other scripts retained byte-identically',all(base[n]==current[n] for n in base if n.startswith('scripts/') and n not in changed))
print(f'RESULT {sum(c for _,c in report)}/{len(report)} pass')
raise SystemExit(0 if all(c for _,c in report) else 1)
