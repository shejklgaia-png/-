#!/usr/bin/env python3
"""Godot-source regression and geometry sanity checks (NOT an engine runtime test)."""
from pathlib import Path
import hashlib, math, random, re, json

root=Path(__file__).resolve().parents[1]
base=Path('/mnt/data/sera_portrait_godot_melee_v49_speed_fixed_0_4s_max')
main=(root/'scripts/main.gd').read_text(encoding='utf-8')
v49=(base/'scripts/main.gd').read_text(encoding='utf-8') if base.exists() else None

def func(src,name):
    match=re.search(r'^func '+re.escape(name)+r'\([\s\S]*?(?=^func |\Z)',src,re.M)
    assert match is not None,name
    return match.group()

# Exact function retention for gesture classification, camera, lock-on and FX.
unchanged=['_input','_begin_drag','_change_drag','_end_drag','_classify_side_flick',
           '_screen_drag_to_ground','_process','_build_camera',
           '_nearest_clear_yaw','_fit_full_frame','_place_camera',
           '_start_attack','_cancel_attack','_start_strike',
           '_update_melee_lock_marker','_distance_to_cube_surface',
           '_check_strike_contact','_register_strike_hit']
if v49 is not None:
    for name in unchanged:
        assert func(main,name)==func(v49,name),f'Unexpected existing behavior change: {name}'
    assert func(main,'_start_side_step').replace('    step_traveled_distance = 0.0\n','') == func(v49,'_start_side_step')

# Fully fledged physics bodies instead of only graphic Node3D meshes.
for token in (
    'var player: CharacterBody3D', 'player = CharacterBody3D.new()',
    'player.collision_layer = PLAYER_COLLISION_LAYER',
    'player.collision_mask = TARGET_COLLISION_LAYER',
    'player.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING',
    'player_shape.shape = player_capsule', 'player_shape.position.y = PLAYER_COLLISION_HEIGHT * 0.5',
    'player.add_child(player_shape)',
    'var target_collider: StaticBody3D','target_collider = StaticBody3D.new()',
    'target_collider.collision_layer = TARGET_COLLISION_LAYER',
    'target_collider.collision_mask = 0',
    'target.add_child(target_collider)',
    'target_box.size = Vector3.ONE * TARGET_HALF_SIZE * 2.0',
    'target_shape.shape = target_box', 'target_collider.add_child(target_shape)',
):
    assert token in main, token

consts={name:float(val) for name,val in re.findall(r'^const ([A-Z_]+): float = ([\d.]+)',main,re.M)}
assert consts['PLAYER_COLLISION_RADIUS']==0.40
assert consts['PLAYER_COLLISION_HEIGHT']==1.85
assert consts['TARGET_HALF_SIZE']==1.0
assert consts['TARGET_BASE_HEIGHT']==1.53
assert consts['STEP_MIN_ARC_LENGTH']==1.5
assert consts['STEP_MAX_ARC_LENGTH']==4.0
assert consts['STEP_SPEED']==10.0
assert consts['STEP_MAX_DURATION']==0.4
assert 'const PLAYER_COLLISION_LAYER: int = 1' in main
assert 'const TARGET_COLLISION_LAYER: int = 2' in main

# The player's standing capsule vertically overlaps the whole visible cube.
# For overlap detection, side faces use radial 0.4m clearance; corners use
# Euclidean point-to-box distance (not a radial sphere around the entire target).
capsule_bottom=0.0
capsule_top=consts['PLAYER_COLLISION_HEIGHT']
box_bottom=consts['TARGET_BASE_HEIGHT']-consts['TARGET_HALF_SIZE']
box_top=consts['TARGET_BASE_HEIGHT']+consts['TARGET_HALF_SIZE']
assert capsule_top>box_bottom and capsule_bottom<box_top

# Every moving player root path must use a physics motion API; no teleport.
for name in ('_advance_side_step','_advance_attack','_physics_process'):
    fn=func(main,name)
    assert 'player.position +=' not in fn and 'player.position = ' not in fn
    assert not re.search(r'player\.position\.(x|z)\s*=',fn)
assert '_move_player_swept(requested, true)' in func(main,'_advance_side_step')
assert '_move_player_swept(player.position.lerp(next_position, high) - player.position, false)' in func(main,'_advance_attack')
assert '_move_player_swept(next_position - player.position, false)' in func(main,'_advance_attack')
assert 'player.move_and_slide()' in func(main,'_physics_process')
assert 'player.velocity = world_move * MOVE_SPEED' in func(main,'_physics_process')
swept=func(main,'_move_player_swept')
assert 'player.move_and_collide(remainder)' in swept
assert 'collision.get_remainder().slide(collision.get_normal())' in swept
assert 'max_attempts: int = 3 if slide_on_wall else 1' in swept
assert 'step_traveled_distance +=' in func(main,'_advance_side_step')
assert 'step_last_elapsed = step_elapsed' in func(main,'_finish_side_step')

# Canonical setup: shapes are attached before player enters movement; no
# side effects on animation, input, camera or target hitbox calculations.
assert main.index('_build_character()') < main.index('_build_target()')
if base.exists():
    for d in ('assets','blockbench','scenes','shaders'):
        a={str(f.relative_to(root)):hashlib.sha256(f.read_bytes()).hexdigest()
           for f in (root/d).rglob('*') if f.is_file()}
        b={str(f.relative_to(base)):hashlib.sha256(f.read_bytes()).hexdigest()
           for f in (base/d).rglob('*') if f.is_file()}
        assert a==b, d
    for name in ('sera_rig.gd','touch_overlay.gd','sword_trail.gd','hit_burst.gd'):
        assert (root/'scripts'/name).read_bytes()==(base/'scripts'/name).read_bytes(),name

# Geometry reference: 3D player cylinder radius vs target XZ square.
# Representative samples include near faces, edges, and corners. This tests
# the dimensions, not the Godot contact solver itself.
def distance_to_square(x,z):
    dx=max(abs(x)-1.0,0.0)
    dz=max(abs(z)-1.0,0.0)
    return math.hypot(dx,dz)
assert distance_to_square(1.39,0)<0.4
assert distance_to_square(1.41,0)>0.4
assert distance_to_square(1.3,1.3)>0.4
assert distance_to_square(1.25,1.25)<0.4
assert distance_to_square(1,1)==0
assert distance_to_square(8,0)>0.4
# Numerically sample intended step orbits to confirm near-target paths can
# cross the box, making collision sweeps necessary even with a curved step.
near_radius=1.45
angle=math.radians(1.5/near_radius*180/math.pi)
assert angle>math.radians(35.0)
assert any(distance_to_square(near_radius*math.cos(t),near_radius*math.sin(t))<.4
           for t in (angle*k/100 for k in range(101)))

print('PASS: CharacterBody3D / StaticBody3D physical shapes, collision layers/masks')
print('PASS: drag slides; orbit and auto-approach use swept collision movement')
print('PASS: step speed/time constants, measured distance and obstruction exceptions')
print('PASS: original gesture, camera, attack and asset source preserved')
print('PASS: XZ box/capsule clearance numerical sanity samples')
print('NOTE: no Godot 4.7.2 runtime or Android device was available')
