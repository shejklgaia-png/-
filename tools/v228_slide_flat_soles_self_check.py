#!/usr/bin/env python3
"""v228: heavy SLIDE levels real soles before the two-bone IK and lowers hips."""
from pathlib import Path
import json
import math
import re

ROOT = Path(__file__).resolve().parents[1]
def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

rig = read("scripts/sera_rig.gd")
eq = read("scripts/sera_equipment.gd")
main = read("scripts/main.gd")
project = read("project.godot")
version = re.search(r'config/name="SERA v(\d+)"', project)
assert version and int(version.group(1)) >= 228
assert "SLIDE_IK_BASE_HIP_DROP: float = 0.07" in eq
assert "SLIDE_IK_MAX_HIP_DROP: float = 0.30" in eq
apply = eq.split("func apply_slide_leg_ik(weight: float = 1.0) -> void:", 1)[1].split("func sync_afterimages()", 1)[0]

# Only B and D training SLIDE, never NEXUS exhibition or gameplay moves.
assert 'not grounding_enabled' in apply
assert '["B", "D"]' in apply
assert 'bool(rig.get("jump_playback"))' in apply
assert 'absf(wearer.global_position.y) > 0.05' in apply
assert 'elif current_clip == BOOST_CLIP and heavy_slide_run_enabled' in rig
assert 'not combat_playback and not guard_playback' in rig

# Full contact requires level shoe orientation BEFORE measuring its triangles
# and solving joints; do not snap only the sole vertex or mesh instance.
assert 'for side in ["L", "R"]:' in apply
assert 'var sole_up: Vector3 = foot.global_basis * Vector3.UP' in apply
assert 'Quaternion(sole_up.normalized(), Vector3.UP)' in apply
assert 'foot.global_basis = Basis(level_rotation) * foot.global_basis' in apply
assert apply.index('foot.global_basis = Basis(level_rotation) * foot.global_basis') < apply.index('var soles: Dictionary = get_active_foot_heights()')
assert apply.index('var soles: Dictionary = get_active_foot_heights()') < apply.index('_solve_slide_two_bone_ik(slide_leg_chains[side], targets[side], side)')
assert 'TRAINING_VISIBLE_FLOOR_Y - sole_world_y' in apply
assert 'hip_drop: float = clampf(maxf(SLIDE_IK_BASE_HIP_DROP,' in apply
assert 'needed_hip_drop + SLIDE_IK_REACH_MARGIN' in apply
assert 'rig.position.y -= hip_drop' in apply
assert 'foot.global_basis = foot_basis' in eq
assert 'rig.call("set_heavy_slide_run_enabled"' in main

# Assert authoring precondition for a flat foot. Both B and D shoes have
# horizontal planar underside and are attached to a Foot pivot without
# any independent shoe rotation. The foot normal is therefore its local +Y.
combined = json.loads(read("models/SERA_BOOSTER_allテスト.bbmodel"))
separate_d = json.loads(read("models/storage/SERA_LOWER_BODY_D_STANDARD_READY.bbmodel"))
b_foot = [mesh for mesh in combined["elements"] if mesh.get("name") in ("Foot_L_Mesh", "Foot_R_Mesh")]
d_foot = [mesh for mesh in separate_d["elements"] if mesh.get("name", "").startswith("LegD_Foot_")]
assert len(b_foot) >= 4 and len(d_foot) == 4
for mesh in b_foot + d_foot:
    assert all(math.isclose(float(value), 0.0) for value in mesh.get("rotation", [0, 0, 0]))
    vertices = list(mesh["vertices"].values())
    bottom = min(float(v[1]) for v in vertices)
    on_bottom = [v for v in vertices if math.isclose(float(v[1]), bottom, abs_tol=1e-8)]
    assert len(on_bottom) >= 4, mesh["name"]
    assert len({float(v[0]) for v in on_bottom}) >= 2, mesh["name"]
    assert len({float(v[2]) for v in on_bottom}) >= 2, mesh["name"]

# v299: C uses the same RUN foot-contact event as the other lower bodies.
# Keep B/D SLIDE IK and contact-only regular RUN pathways independent.
assert 'equipment_handler.call("snap_run_contact_foot_to_floor", side)' in rig
assert 'equipment_handler.call("restore_run_contact_height")' in rig
assert 'equipment_handler.call("smooth_bird_grounding", delta)' not in rig
print("PASS v228 B/D level heel-to-toe soles, hip crouch, IK order and isolation")
