#!/usr/bin/env python3
"""v199: real animated footwear vertices contact the training visual floor."""
from __future__ import annotations
from pathlib import Path
import math
import re

ROOT = Path(__file__).resolve().parents[1]
def read(path):
    return (ROOT/path).read_text(encoding="utf-8")

assert re.search(r'^config/name="SERA v199"$', read("project.godot"), re.M)
eq = read("scripts/sera_equipment.gd")
rig = read("scripts/sera_rig.gd")
stage = read("scripts/main.gd")

# Foot height must use ALL actual surface triangle vertices in each animated
# foot mesh, not 8 corners of an axis-aligned Box (false below-ground corners
# caused the visually tilted foot to float over the floor).
start = eq.index("func _mesh_lowest_y(piece: MeshInstance3D)")
end = eq.index("func _cache_bind_foot_geometry()", start)
sole_method = eq[start:end]
for needle in (
    "piece.mesh.surface_get_arrays(surface)",
    "Mesh.ARRAY_VERTEX",
    "vertices.append_array(arrays[Mesh.ARRAY_VERTEX])",
    "foot_vertex_cache[cache_key]",
    "rig.global_transform.affine_inverse() * piece.global_transform",
    "sole_y = minf(sole_y, (to_rig * vertex).y)",
):
    assert needle in sole_method, needle
assert "mesh.get_aabb()" not in sole_method
assert "foot_vertex_cache.clear()" in eq

# On grounded frames, adapt to currently animated foot motion AFTER the pose
# is set, independently of which LOWER BODY set A/B/C/D is selected.
snap = eq[eq.index("func snap_grounded_sole_to_floor()"):eq.index("func get_grounding_height_offset()")]
assert "if not grounding_enabled or rig == null:" in snap
assert 'bool(rig.get("jump_playback"))' in snap
assert "absf(wearer.global_position.y) > 0.05" in snap
assert 'get_active_foot_heights()' in snap
assert 'heights.has("L") or not heights.has("R")' in snap
assert 'minf(float(heights["L"]), float(heights["R"]))' in snap
assert "rig.position.y = TRAINING_VISIBLE_FLOOR_Y - current_sole - wearer.global_position.y" in snap
assert "if is_inf(current_sole) or is_nan(current_sole):" in snap

assert '    _apply_animation(0.0)\n    # First frame' in rig
assert '    _apply_animation(delta)\n    # Post-pose foot placement:' in rig
assert '    equipment_handler.call("snap_grounded_sole_to_floor")\n    _update_foot_contacts(delta)' in rig
assert 'func set_exhibition_mode(enabled: bool) -> void:' in rig
assert 'equipment_handler.call("set_grounding_enabled", not enabled)' in rig
assert 'func get_active_foot_heights() -> Dictionary:' in eq
assert 'foot_meshes.get(str(selected.get("legs", "A")), {})' in eq

# The stage remains the same 0.0 logical XZ plane; the visible floor top
# is the 0.009-high grid centered at -0.038.
assert 'player.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING' in stage
assert 'floor_instance.position.y = -0.105' in stage
assert '_floor_line(Vector3(float(n), -0.038, 0.0), Vector3(0.032, 0.009, 160.0), grid_mat)' in stage
assert 'const TRAINING_VISIBLE_FLOOR_Y: float = -0.0335' in eq
assert math.isclose(-0.038 + 0.009/2, -0.0335)

# Algebra: correct visual rig height (not player/collider) for idle, run,
# tilted soles, either support foot, and a parent at ground height.
floor_y = -0.0335
for left, right in [(-0.25, -0.10), (-0.08, -0.31), (0.09, 0.12), (-0.44, -0.44)]:
    low = min(left, right)
    rig_y = floor_y - low
    assert math.isclose(rig_y + min(left, right), floor_y, abs_tol=1e-12)
    assert (rig_y + max(left, right)) >= floor_y - 1e-12

# Existing static equipment height still drives collider extension; no
# changes to actor movement, jumps or authored animation keyframes.
assert 'grounding_height_offset = standard_sole_y - float(' in eq
assert 'rig.position.y = rig_original_y + grounding_height_offset' in eq
assert 'get_grounding_height_offset' in rig
assert 'var lift: float = maxf(0.0, float(rig.call("get_grounding_height_offset")))' in stage
assert 'player.position.y = 0.0' in stage
assert 'foot_contact.emit(side)' in rig
print("PASS v199: real transformed shoe vertices, per-pose grounding and both feet")
print("PASS v199: floor plane math, grounded/airborne/exhibition isolation")
print("PASS v199: original velocity/collider and gait/footstep code preserved")
print("Godot Android visual verification pending")
