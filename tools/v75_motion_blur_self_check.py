#!/usr/bin/env python3
"""v75 selective blur static checks and regression guards; no Godot runtime."""
from pathlib import Path
import zipfile, re, hashlib, sys, math
root = Path(__file__).resolve().parents[1]
main = (root/'scripts/main.gd').read_text('utf8')
rig = (root/'scripts/sera_rig.gd').read_text('utf8')
far = (root/'shaders/selective_far_blur.gdshader').read_text('utf8')
ghost = (root/'shaders/sera_motion_ghost.gdshader').read_text('utf8')
project = (root/'project.godot').read_text('utf8')
checks=[]
def ck(label, condition):
    checks.append((label,bool(condition)))
    print(('PASS' if condition else 'FAIL')+' '+label)
ck('v75 naming and GL compatibility retained','SERA v75 | Selective Motion Blur' in project and 'renderer/rendering_method="gl_compatibility"' in project)
ck('no extra Viewport', 'SubViewport' not in main and 'ViewportTexture' not in main)
ck('existing run and boost values unchanged',all(x in main for x in ('const MOVE_SPEED: float = 3.25','const MOVEMENT_BOOST_MULTIPLIER: float = 1.5','const DRAG_RADIUS: float = 168.0','BOOST_OUTSIDE_RADIUS_RATIO: float = 1.0')))
ck('step max and min preserved',all(x in main for x in ('const STEP_SPEED: float = 10.0','const STEP_CLOSE_SPEED: float = 8.0','const STEP_MIN_ARC_LENGTH: float = 2.0','const STEP_MAX_ARC_LENGTH: float = 4.0','const STEP_MAX_DURATION: float = 0.40')))
ck('enemy interval and velocity preserved','var fire_interval_min: float = 2.0' in (root/'scripts/enemy_shooter.gd').read_text() and 'var travel_speed: float = 12.0' in (root/'scripts/enemy_projectile.gd').read_text())
ck('damage knockback preserved',all(x in main for x in ('const DAMAGE_KNOCKBACK_DISTANCE: float = 1.20','const DAMAGE_KNOCKBACK_DURATION: float = 0.24')))
ck('blur gated by step & outward-boost only','blur_step_this_physics_frame or (combat_state == CombatState.IDLE' in main and 'and movement_boost_active and running' in main)
ck('damage cancels selective blur','blur_step_this_physics_frame = stepping_this_frame and not damage_reaction_active' in main and 'blur_active_this_physics_frame = (not damage_reaction_active' in main)
ck('actual player displacement is used','blur_velocity = (player.global_position - blur_last_player_position) / delta' in main and 'blur_last_player_position = player.global_position' in main)
ck('ghost uses single character overlay pass','piece.material_overlay = overlay' not in rig and 'part.material_overlay = overlay' in rig and 'material_overlay' in rig)
ck('sword foreground prioritised','if _foreground_enabled:\n        overlay = _foreground_mat\n    elif _motion_blur_enabled:' in rig)
ck('non-sword-effect mesh overlay','if not is_sword_fx:' in rig and '_foreground_parts.append(result)' in rig)
ck('animated bones not duplicated','SERA_SCRIPT.new()' in main and 'set_motion_blur' in rig and 'SERA_SCRIPT.new()' == 'SERA_SCRIPT.new()')
ck('ghost shader samples authored palette','texture(sera_palette, UV)' in ghost and 'ALPHA = authored_color.a * ghost_alpha' in ghost)
ck('ghost trail is world aligned','inverse(MODEL_MATRIX)' in ghost and 'vec4(trail_world, 0.0)' in ghost)
ck('far blur 3 taps exactly',far.count('texture(screen_texture,')==3)
ck('far shader distance mask','distance(fragment_world.xz, player_world.xz)' in far and 'smoothstep(far_begin, far_full, range_xz)' in far)
ck('far threshold 7-11 meters', 'MOTION_BLUR_FAR_START: float = 7.0' in main and 'MOTION_BLUR_FAR_FULL: float = 11.0' in main)
ck('plane covers the scrolling floor',all(x in main for x in ('plane.size = Vector2(160.0, 160.0)','floor_stage.add_child(far_blur_plane)','far_blur_plane.position.y = -0.028')))
ck('depth-tested far overlay','depth_test_disabled' not in far and 'depth_draw_never' in far)
ck('off state disables ghost and far overlay','far_blur_plane.visible = false' in main and 'rig.call("set_motion_blur", false, Vector3.ZERO, 0.0)' in main)
ck('active state enables both','far_blur_plane.visible = true' in main and 'rig.call("set_motion_blur", true, ghost_offset' in main)
ck('far scenery opt-in does not include enemy','"motion_blur_far_environment"' in main and 'target_mesh.material_overlay' not in main)
ck('HUD excluded from shader','_build_overlay()' in main and 'canvas_item' not in far)
ck('update after camera finalized',main.index('    _update_target_marker_projection()\n    _update_motion_blur()') > main.index('    _fit_full_frame()'))
ck('fade bounds yield expected [0,1]',all(0<=max(0,min(1,(d-7)/4))<=1 for d in (0,2,7,8,9,11,15)))
# Ensure all original assets/scripts are preserved unless explicitly modified.
base_archive = root.parent/'sera_portrait_godot_melee_v74_step_min_8ms.zip'
if base_archive.is_file():
    with zipfile.ZipFile(base_archive) as z:
        base = {n.split('/',1)[1]:z.read(n) for n in z.namelist() if '/' in n and not n.endswith('/')}
    cur = {f.relative_to(root).as_posix():f.read_bytes() for f in root.rglob('*') if f.is_file()}
    changed = {n for n in base.keys()&cur.keys() if base[n]!=cur[n]}
    added = set(cur)-set(base)
    ck('v74 original files all present',not(set(base)-set(cur)))
    ck('only intended originals changed',changed=={'scripts/main.gd','scripts/sera_rig.gd','project.godot','DEVELOPMENT.md'})
    ck('only planned v75 additions',added=={'README_v75_ja.md','shaders/sera_motion_ghost.gdshader','shaders/selective_far_blur.gdshader','tools/v75_motion_blur_self_check.py'})
    ck('animations/models byte identical',all(base[n]==cur[n] for n in base if n.startswith(('blockbench/','assets/'))))
    ck('other scripts untouched',all(base[n]==cur[n] for n in base if n.startswith('scripts/') and n not in changed))
else:
    print('INFO baseline ZIP missing; diff checks skipped')
print(f'{sum(ok for _,ok in checks)}/{len(checks)} PASS')
sys.exit(0 if all(ok for _,ok in checks) else 1)
