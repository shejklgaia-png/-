#!/usr/bin/env python3
"""SERA v227: B/D-only SLIDE two-bone IK and isolation regression."""
from pathlib import Path
import math
import re

ROOT = Path(__file__).resolve().parents[1]
def read(name):
    return (ROOT / name).read_text(encoding="utf-8")

rig = read("scripts/sera_rig.gd")
eq = read("scripts/sera_equipment.gd")
main = read("scripts/main.gd")
project = read("project.godot")
version = re.search(r'config/name="SERA v(\d+)"', project)
assert version and int(version.group(1)) >= 227
assert 'SLIDE_BOOST_POSE_MAX_WEIGHT: float = 0.50' in rig
assert 'locomotion_mode = "slide"' in rig
assert 'var sliding: bool = (moving and heavy_slide_run_enabled' in rig

tick = rig.split("    _apply_animation(delta)", 1)[1].split(
    "func _run_heading_from_weights", 1)[0]
assert tick.index('restore_grounding_baseline') < tick.index('restore_run_contact_foot_positions')
assert tick.index('restore_run_contact_foot_positions') < tick.index('apply_slide_leg_ik')
assert 'elif current_clip == BOOST_CLIP and heavy_slide_run_enabled' in tick
for condition in ("not combat_playback", "not guard_playback", "not damage_playback",
                  "not jump_playback", "not step_playback"):
    assert condition in tick.split('elif current_clip == BOOST_CLIP and heavy_slide_run_enabled', 1)[1]
assert tick.count('equipment_handler.call("apply_slide_leg_ik", slide_blend_weight)') == 1
assert tick.count('equipment_handler.call("snap_grounded_sole_to_floor")') == 1
assert 'elif current_clip in RUN_CLIPS and not step_playback:' in tick
assert 'equipment_handler.call("smooth_bird_grounding", delta)' in tick
assert '_update_foot_contacts(delta)' in tick

cache = eq.split("func _cache_slide_leg_chains()", 1)[1].split("func _solve_slide_two_bone_ik(", 1)[0]
for bone in ("Thigh_", "LowerLeg_", "Foot_"):
    assert bone in cache
assert 'for side in ["L", "R"]' in cache
solver = eq.split("func _solve_slide_two_bone_ik(", 1)[1].split("func apply_slide_leg_ik()", 1)[0]
for expected in ("Quaternion(", "thigh.global_basis = Basis(hip_turn) * thigh.global_basis",
                 "knee.global_basis = Basis(knee_turn) * knee.global_basis",
                 "foot.global_basis = foot_basis",
                 "upper * upper + distance * distance - lower * lower",
                 "SLIDE_IK_REACH_MARGIN", "Vector3.LEFT if side == \"L\" else Vector3.RIGHT"):
    assert expected in solver, expected
apply = eq.split("func apply_slide_leg_ik(weight: float = 1.0)", 1)[1].split("func sync_afterimages()", 1)[0]
for expected in ('not grounding_enabled', '["B", "D"]', 'get_active_foot_heights()',
                 'absf(wearer.global_position.y) > 0.05', 'bool(rig.get("jump_playback"))',
                 'TRAINING_VISIBLE_FLOOR_Y - sole_world_y',
                 'rig.position.y -= hip_drop',
                 '_solve_slide_two_bone_ik(slide_leg_chains[side], targets[side], side)'):
    assert expected in apply, expected
assert 'const SLIDE_IK_MAX_HIP_DROP: float = 0.30' in eq
assert 'rig.call("set_heavy_slide_run_enabled"' in main
assert 'foot_contact.emit(side)' in rig
assert 'func set_grounding_enabled(enabled: bool)' in eq

# Analytical check: the chosen cosine-law knee is on both limb spheres, for
# assorted reachable targets and unequal segment lengths (not just symmetry).
for upper, lower in [(0.26, 0.46), (0.33, 0.34), (0.43, 0.27)]:
    for target_distance in (abs(upper - lower) + 0.01,
                            (upper + lower) * 0.62,
                            upper + lower - 0.01):
        clamped = max(abs(upper - lower) + 0.003,
                      min(upper + lower - 0.003, target_distance))
        along = (upper**2 + clamped**2 - lower**2) / (2.0 * clamped)
        away = math.sqrt(max(0.0, upper**2 - along**2))
        assert math.isclose(math.hypot(along, away), upper, abs_tol=1e-10)
        assert math.isclose(math.hypot(clamped - along, away), lower, abs_tol=1e-10)
print("SERA v227 slide two-foot IK source isolation and two-bone geometry checks passed")
