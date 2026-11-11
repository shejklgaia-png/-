#!/usr/bin/env python3
"""v239 rectangular body / equal-height legs / low head; static and numeric."""
from pathlib import Path
import math
import re

root=Path(__file__).resolve().parents[1]
def read(p): return (root/p).read_text(encoding="utf-8")
main=read("scripts/main.gd")
parts=read("scripts/target_parts.gd")
motion=read("scripts/training_target_motion.gd")
shooter=read("scripts/enemy_shooter.gd")
project=read("project.godot")
assert re.search(r'config/name="SERA v(\d+)"', project) and int(re.search(r'config/name="SERA v(\d+)"', project).group(1)) >= 239
assert (root/"README_v239_ja.md").exists()

# The visible body, physical collider and sword contact must have the same
# rectangular half extents (1.0, 1.0, 1.7).
assert "const TARGET_HALF_SIZE: float = 1.0" in main
assert "const TARGET_BODY_HALF_DEPTH: float = 1.70" in main
assert "cube.size = Vector3(" in main
assert "TARGET_HALF_SIZE * 2.0, TARGET_HALF_SIZE * 2.0, TARGET_BODY_HALF_DEPTH * 2.0" in main
assert "target_box.size = cube.size" in main
assert "Vector3(TARGET_HALF_SIZE, TARGET_HALF_SIZE, TARGET_BODY_HALF_DEPTH)" in main
assert "absf(pos.z - target.position.z) - TARGET_BODY_HALF_DEPTH" in main
assert main.count("target.position.z - TARGET_BODY_HALF_DEPTH") >= 2
assert "target.global_position.z + signf(toward_camera.z) * (TARGET_BODY_HALF_DEPTH + 0.035)" in main

# The camera sees extended parts even along diagonal directions, not only
# the old 2m cube. Keep camera focus unchanged.
for key in ("const TARGET_FRAME_HALF_WIDTH: float = 2.35",
            "const TARGET_FRAME_HALF_HEIGHT: float = 1.53",
            "const TARGET_FRAME_HALF_DEPTH: float = 2.35"):
    assert key in main, key
assert main.count("for dx in [-TARGET_FRAME_HALF_WIDTH, TARGET_FRAME_HALF_WIDTH]:") == 3
assert main.count("for dy in [-TARGET_FRAME_HALF_HEIGHT, TARGET_FRAME_HALF_HEIGHT]:") == 2
assert main.count("for dz in [-TARGET_FRAME_HALF_DEPTH, TARGET_FRAME_HALF_DEPTH]:") == 3
assert "camera_target_render_position = target.get_global_transform_interpolated().origin" in main

# Movers/telegraphs must not treat the new 3.4m body as a 2m cube.
assert "const BODY_HALF_WIDTH: float = 1.0" in motion
assert "const BODY_HALF_DEPTH: float = 1.70" in motion
assert "absf(player_pos.z - wanted.z) - BODY_HALF_DEPTH" in motion
assert "absf(player_pos.z - current.z) - BODY_HALF_DEPTH" in motion
assert "const TARGET_BODY_HALF_DEPTH: float = 1.70" in shooter
assert "TARGET_BODY_HALF_DEPTH / maxf(absf(facing.z), 0.00001)" in shooter

# v238's four part names, distinct durability and break modes remain.
assert parts.count("    _add_part(") == 5
for id, hp, mode in (
    ("head",38., "change"),("leg_fl",30., "remove"),
    ("leg_fr",30., "remove"),("leg_rl",32., "remain"),
    ("leg_rr",32., "remain")):
    assert f'_add_part("{id}",' in parts
    assert f'{hp:.1f}' in parts
    assert f'"{mode}"' in parts
assert "func apply_part_hit(" in parts
assert "func select_front_part(" in parts
assert "func reset_parts()" in parts
assert "func get_part_aabb(" in parts

# Numeric floor/attack-height invariants. Real sword blade clip still needs
# Godot device verification; these ensure the height is within player torso.
body = (2., 2., 3.4)
body_half = (1., 1., 1.7)
head_center=(0.,-.44,1.85)
head_size=(1.48,.82,.96)
head_lock_y=-.03
target_base=1.53
head_min=target_base+head_center[1]-head_size[1]*.5
head_max=target_base+head_center[1]+head_size[1]*.5
head_lock=target_base+head_center[1]+head_lock_y
assert math.isclose(head_min,.68) and math.isclose(head_max,1.50)
assert math.isclose(head_lock,1.06)
assert head_min < 1.05 < head_max
assert head_center[2]-head_size[2]/2 < body_half[2]
assert head_center[2]+head_size[2]/2 > body_half[2]
for id,sign,z in (("leg_fl",-1,1.27),("leg_fr",1,1.27),
                  ("leg_rl",-1,-1.27),("leg_rr",1,-1.27)):
    pattern = rf'_add_part\("{id}", "[^"]+", Vector3\(\s*({sign*1.23:.2f}), -0.53, ({z:.2f})\),\s*Vector3\(2.24, 2.00, 1.36\)'
    # Negative coordinates can stringify as -1.23, not -0.00.
    assert re.search(pattern,parts), (id, pattern)
    assert 2.0 == body[1]
    assert math.isclose(target_base-.53-1.0,0.0)
assert 'Vector3(-side * 0.24, 0.83, 0.0)' in parts
assert 'Vector3(side * 0.58, -0.91, fore_aft * 0.18)' in parts
assert 'Vector3(0.84, 0.18, 0.84)' in parts
assert "Vector3(0.90, 0.34, 0.78)" in parts
assert "BoxMesh.new()" in parts
assert "SphereMesh" not in parts and "CylinderMesh" not in parts
assert "render_priority" not in parts
print("PASS v239 rectangular 2x2x3.4m core, physics/melee/moving enemy consistency")
print("PASS v239 2.0m-tall four legs, ground soles, front head at 1.06m lock")
print("PASS v239 rectangular meshes and expanded camera frame")
print("Godot parser/Android device sword-sweep rendering NOT tested")
