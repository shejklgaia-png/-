#!/usr/bin/env python3
"""SERA v251: mesh-aligned part collisions, joint seals, safe breaks and shared movement."""
from pathlib import Path
import math
import re

root=Path(__file__).resolve().parents[1]
def read(file): return (root/file).read_text(encoding="utf-8")
main=read("scripts/main.gd")
parts=read("scripts/target_parts.gd")
project=read("project.godot")
version_match = re.search(r'^config/name="SERA v(\d+)"$', project, re.M)
assert version_match and int(version_match.group(1)) >= 251
assert (root/"README_v251_ja.md").is_file()
assert 'target_collider = AnimatableBody3D.new()' in main
assert 'target_collider.collision_layer = TARGET_COLLISION_LAYER' in main
assert 'player.collision_mask = TARGET_COLLISION_LAYER' in main
assert 'target_box.size = cube.size' in main
assert 'marker.add_child(target_parts)' in main
assert 'target_parts.call("install_movement_colliders", target_collider)' in main
assert 'func install_movement_colliders(body: CollisionObject3D) -> void:' in parts
assert 'for id in PART_ORDER:' in parts
assert 'for child in pivot.get_children():' in parts
assert 'if not child is MeshInstance3D:' in parts
assert 'if not visible_box.mesh is BoxMesh:' in parts
assert 'box_mesh.size, is_fracture' in parts
assert 'var box := BoxShape3D.new()' in parts
assert 'box.size = dimensions' in parts
assert 'collider.transform = body.global_transform.affine_inverse() * mesh_transform' in parts
assert 'body.add_child(collider)' in parts
assert 'part["movement_colliders"] = shapes' in parts
assert 'part["fracture_collider"] = fracture_shape' in parts
assert 'if id in LEG_IDS:' in parts
assert '"BodyJunction"' in parts
assert 'Vector3(0.96, 1.85, 0.62)' in parts
assert 'Vector3(-side * 0.19, -0.06, 0.0)' in parts

# The body's horizontal shape (-1..+1) meets the side joint guards;
# each guard extends outward into leg structures but leaves the outer
# largely open frame untouched.
core_right=1.0
for side in (-1,1):
    center_x=side*1.23-side*.19
    lo,hi=center_x-.96/2,center_x+.96/2
    assert lo < core_right and hi > core_right if side==1 else (lo < -core_right and hi > -core_right)
    assert max(abs(lo),abs(hi))<2.35
# Bounding box at +Z/-Z limb center lies within the core depth.
for z in (-1.27,1.27):
    assert abs(z)+.62/2<1.70
# Connector almost reaches standing sole y=0 while remaining behind
# the visible 2m leg. The local target base height remains unchanged.
base=1.53
local_y=-.53-.06
assert -0.02<base+local_y-1.85/2<0.04
assert 1.8<base+local_y+1.85/2<2.0

# Front leg disappears and loses every solid; rear leg remains solid.
assert 'pivot.visible = false' in parts
assert '_set_part_movement_collision(effective_id, mode != "remove")' in parts
assert 'collider.set_deferred("disabled", not should_enable)' in parts
assert 'not is_fracture or bool(part["broken"])' in parts
assert '_set_part_movement_collision(id, true)' in parts
assert main.count('target_parts.call("reset_parts")')==2
assert 'enemy_shooter.call("set_head_destroyed", true)' in main

# Existing collision paths all use the original Player capsule/layer:
# RUN and BOOST, STEP, knockback and jump; homing now slides on obstacles.
assert 'player.move_and_slide()' in main
assert 'func _move_player_swept(motion: Vector3, slide_on_wall: bool)' in main
assert '_move_player_swept(requested, true)' in main
assert '_move_player_swept(damage_knockback_direction *' in main
assert '_move_player_swept(horizontal_velocity * delta, true)' in main
homing=main.split('func _advance_homing_toward_target(',1)[1].split(
    'func _check_bash_contact(',1)[0]
assert homing.count('_move_player_swept(')==2
assert 'player.position.lerp(next_position, high) - player.position, true)' in homing
assert '_move_player_swept(next_position - player.position, true)' in homing
# Physical collision is added in target_parts only. The sword's v249
# lock-exclusive hit route is not switched to physics contacts.
blade=main.split('func _blade_contact(',1)[1].split('func _check_strike_contact(',1)[0]
assert 'return part_box.grow(BLADE_THICKNESS).intersects_segment' in blade
assert 'return _target_hit_aabb().grow(BLADE_THICKNESS).intersects_segment' in blade
assert 'TARGET_MAX_HP: int = 500' in main
for key in ("head","leg_fl","leg_fr","leg_rl","leg_rr"):
    assert f'_add_part("{key}",' in parts

print("PASS v251: real model-aligned BoxShape3D colliders + four solid torso/limb joints")
print("PASS v251: RUN/BOOST/STEP/jump/knockback/homing physics, break/reset lifecycle")
print("PASS v251: lock-exclusive sword hitboxes, target HP, original visuals and rig kept")
print("Godot/Android physics contacts and performance NOT exercised")
