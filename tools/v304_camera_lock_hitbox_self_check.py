#!/usr/bin/env python3
"""v304: each of BODY, HEAD and all four limbs has a separate 115% camera-only box."""
from pathlib import Path

# v317: AUTO state remains in main; paired-ray selection moved to a pure module.
from pathlib import Path as _LockPath
LOCK_MODULE = (_LockPath(__file__).resolve().parents[1] / "scripts/sera_lock_management.gd").read_text(encoding="utf-8")
import re
R=Path(__file__).resolve().parents[1]
src=(R/"scripts/target_parts.gd").read_text(encoding="utf-8")
game=(R/"scripts/main.gd").read_text(encoding="utf-8")
manifest=(R/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
version=(R/"project.godot").read_text(encoding="utf-8")
assert int(re.search(r'config/name="SERA v(\d+)"',version).group(1)) >= 304
assert (R/"docs/history/release_notes/README_v304_ja.md").exists()
assert "const CAMERA_LOCK_VOLUME_SCALE: float = 1.15" in src
builder=src.split("func _create_camera_lock_volume(",1)[1].split(
    "func _camera_lock_volume_distance(",1)[0]
for token in (
    "Area3D.new()",
    "area.collision_layer = 0",
    "area.collision_mask = 0",
    "area.monitoring = false",
    "area.monitorable = false",
    "CollisionShape3D.new()",
    'shape.name = "CameraOnlyBox"',
    "BoxShape3D.new()",
    "box.size = (model_size + extra_size) * CAMERA_LOCK_VOLUME_SCALE",
    "owner.add_child(area)",
):
    assert token in builder,token
distance=src.split("func _camera_lock_volume_distance(",1)[1].split(
    "func _ready() -> void:",1)[0]
for token in (
    "area.get_node_or_null(",
    "collision.shape is BoxShape3D",
    "AABB(-size * 0.5, size).intersects_segment(",
    "area.to_local(origin), area.to_local(destination)",
    "area.to_global(entry)",
    'return origin.distance_squared_to(area.to_global(entry))',
    "if not is_targetable(id):",
    'parts[id]["camera_lock_area"]',
    "core_camera_lock_area",
):
    assert token in distance,token
ready=src.split("func _ready() -> void:",1)[1].split("func _make_box(",1)[0]
assert "BodyCameraLockArea" in ready
assert '"CameraLockArea"' in src
assert 'var camera_area: Area3D = _create_camera_lock_volume(' in src
assert '"camera_lock_area": camera_area' in src
assert "HEAD_LOCK_UPWARD_EXTENSION_METERS" in src
assert "HEAD_LOCK_FORWARD_EXTENSION_METERS" in src
assert 'shift = Vector3(0.0, HEAD_LOCK_UPWARD_EXTENSION_METERS * 0.5,' in src
dual=src.split("func _parallel_lock_part_distance(",1)[1].split(
    "func actor_parallel_lines_hits_part(",1)[0]
for token in (
    "_camera_lock_body_volume_distance(segments[0], segments[1])",
    "_camera_lock_body_volume_distance(segments[2], segments[3])",
    "_camera_lock_part_volume_distance(segments[0], segments[1], id)",
    "_camera_lock_part_volume_distance(segments[2], segments[3], id)",
    "if first == INF or second == INF:",
    "return maxf(first, second)",
):
    assert token in dual,token
for legacy in ("_camera_center_line_part_distance(","_camera_center_line_body_distance("):
    assert legacy not in dual,legacy
# Legacy exact-mesh line checks remain usable by historic tests. Combat
# AABBs and physical collision are untouched.
legacy=src.split("func _camera_center_line_part_distance(",1)[1].split(
    "func _camera_center_line_body_distance(",1)[0]
assert "for child in pivot.get_children():" in legacy
assert "intersects_segment(" in legacy
assert 'if id == "head":' in legacy
assert 'head_size.y + HEAD_LOCK_UPWARD_EXTENSION_METERS' in legacy
combat=src.split("func get_part_aabb(id: String) -> AABB:",1)[1].split(
    "func get_part_defense(",1)[0]
assert 'var dimensions: Vector3 = part["size"]' in combat
assert "CAMERA_LOCK_VOLUME_SCALE" not in combat
movement=src.split("func install_movement_colliders(",1)[1].split(
    "func _set_part_movement_collision(",1)[0]
assert "CAMERA_LOCK_VOLUME_SCALE" not in movement
assert "CAMERA_LOCK_VOLUME_SCALE" not in game
assert 'LOCK_MANAGEMENT.select_auto_part(' in game
assert 'func actor_parallel_lines_hits_part(' in src
assert '"actor_parallel_lines_hits_part",' not in game.split(
    "func _acquire_stable_camera_part(delta: float,",1)[1].split(
    "# v305: yaw SERA toward the actual current LOCK target.",1)[0]
assert "var lock_lines_visible: bool = false" in game
for p in ("py tools/v304_camera_lock_hitbox_self_check.py",
          "gd tools/v304_camera_lock_hitbox_runtime_check.gd"):
    assert p in manifest,p
print("V304_CAMERA_LOCK_HITBOX_STATIC_PASS")

# The authoritative selection API is still the same actor-origin dual-line method.
assert '"select_actor_parallel_lines_part", actor_origin, target_center' in LOCK_MODULE
