#!/usr/bin/env python3
"""v350 Bittaran camera-only 2x shin selection volumes, world Y locked."""
from pathlib import Path
r = Path(__file__).resolve().parents[1]
parts = (r/"scripts/bittaran_parts.gd").read_text(encoding="utf-8")
battle = (r/"scripts/bittaran_battle.gd").read_text(encoding="utf-8")
for needle in [
    "const SHIN_SELECTION_VOLUME_SCALE: float = 2.0",
    "var shin_selection_standing: Dictionary = {}",
    "func _shin_mesh_bounds(id: String) -> AABB:",
    "_append_mesh_bounds(bone_nodes[id], vertices, false)",
    "func get_shin_selection_box(id: String) -> AABB:",
    '"world_y": authored_shin.get_center().y',
    '"box_size": authored_shin.size * SHIN_SELECTION_VOLUME_SCALE',
    "lock_center = selection_box.get_center()",
    "lock_size = selection_box.size",
    "box.size = lock_size",
    "box_solid.size = bounds.size",
    'physical.set_deferred("global_transform",'
]:
    assert needle in parts, needle
assert 'target_parts.call("sync_bittaran_parts")' in battle
assert 'area.collision_layer = 0' in parts
assert 'area.collision_mask = 0' in parts
assert 'area.monitoring = false' in parts
assert 'area.monitorable = false' in parts
print("PASS v350 Bittaran 2x SHIN lock-only meshes, fixed Y, combat unchanged")
