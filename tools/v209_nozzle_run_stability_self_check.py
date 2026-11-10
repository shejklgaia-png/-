#!/usr/bin/env python3
"""SERA v209: physical nozzle hinge and flicker-free RUN transitions."""
from pathlib import Path
import json
import math

ROOT = Path(__file__).resolve().parents[1]
read = lambda path: (ROOT / path).read_text(encoding="utf-8")
fx = read("scripts/back_thruster_fx.gd")
eq = read("scripts/sera_equipment.gd")
rig = read("scripts/sera_rig.gd")
main = read("scripts/main.gd")
assert 'config/name="SERA v209"' in read("project.godot")

# Blockbench authored group pivots remain the only physical nozzle hinges.
model = json.loads(read("models/SERA_BOOSTER_allテスト.bbmodel"))
groups = {group["name"]: group for group in model["groups"]}
for side in ("Thruster_L", "Thruster_R"):
    assert side in groups and len(groups[side]["origin"]) == 3
    assert groups[side]["rotation"] == [0, 0, 0]
for part in ("Thruster_L_Outer", "Thruster_L_Inner", "Thruster_R_Outer", "Thruster_R_Inner"):
    assert any(el["name"] == part for el in model["elements"])
assert 'pivot.add_child(piece)' in eq
assert 'pivot.add_child(fx)' in eq
assert 'fx.call("set_exhaust", active and str(set_id) == selected_booster,' in eq
assert "nozzle_rest_rotation = nozzle.quaternion" in fx
assert "nozzle_parent.global_transform.basis * Basis(nozzle_rest_rotation)" in fx
assert "rest_basis.inverse() * world_exhaust_direction.normalized()" in fx
assert "nozzle.quaternion = (nozzle_rest_rotation" in fx
assert "Quaternion(Vector3.UP, steering_yaw)" in fx
assert "Quaternion(Vector3.RIGHT, steering_pitch)" in fx
assert "steering_yaw = lerp_angle(steering_yaw, yaw, ease)" in fx
assert "steering_pitch = lerp_angle(steering_pitch, pitch, ease)" in fx
assert "rotation.y = lerp_angle(" not in fx
assert "rotation.x = lerp_angle(" not in fx
assert "visible = enabled" in fx
for token in ("PI * 80.0 / 180.0", "PI * 90.0 / 180.0",
              "PI * 1.0 / 180.0", "TURN_TIME: float = 0.075"):
    assert token in fx

# RUN gait facing: no per-frame flip from crossing sign(x) behind target.
retreat = rig.split("func _run_yaw_for_direction(", 1)[1].split("func _smooth_visual_direction(", 1)[0]
assert "run_retreat_turn_sign" in retreat
assert "direction.x >= 0.0 else -1.0" not in retreat
assert "run_retreat_turn_sign = 1.0 if direction.x >= 0.0 else -1.0" in rig
assert "run_retreat_blend < 0.05 and absf(direction.x) > 0.02" in rig
assert "RUN_MODE_HYSTERESIS_DEGREES" in rig

# Mid-transition x-crossing at center-back is continuous for a held side.
def wrap(v):
    return (v + math.pi) % (2 * math.pi) - math.pi
def yaw(x, y, blend, turn_sign):
    return wrap(-math.atan2(x, y) + math.pi * blend * turn_sign)
for alpha in (0.05, 0.33, 0.66, 0.95):
    for sign in (-1, 1):
        a, b = yaw(-0.0001, -1, alpha, sign), yaw(0.0001, -1, alpha, sign)
        assert abs(wrap(a - b)) < math.radians(0.1)

# A RUN footfall may touch the floor but must not teleport the whole actor
# for just one frame. WAIT keeps its original whole-character sole alignment.
run_update = rig.split("func _update_foot_contacts(delta: float)",1)[1].split("func _build_model(",1)[0]
assert 'equipment_handler.call("snap_run_contact_foot_to_floor", side)' in run_update
assert 'foot_contact.emit(side)' in run_update
assert "snap_grounded_sole_to_floor" not in run_update
assert 'equipment_handler.call("restore_run_contact_foot_positions")' in rig
assert 'equipment_handler.call("snap_grounded_sole_to_floor")' in rig
contact = eq.split("func snap_run_contact_foot_to_floor(side: String)",1)[1].split("func get_grounding_height_offset()",1)[0]
assert "get_active_foot_heights()" in contact
assert "TRAINING_VISIBLE_FLOOR_Y - current_world_y" in contact
assert "piece.global_position += Vector3.UP * adjustment" in contact
assert "rig.position.y =" not in contact
assert "player.position" not in contact
assert "contact_foot_bind_positions[piece.get_instance_id()] = piece.position" in eq
assert "piece.position = contact_foot_bind_positions[piece.get_instance_id()]" in eq

# No change to actual BOOST, EN recovery or gesture input logic.
for token in (
    "const EN_RECOVERY_UNLOCK_RATIO: float = 0.60",
    "if was_energy_exhausted and not energy_exhausted:",
    "const BOOST_EXIT_RADIUS_RATIO: float = 0.90",
    "const BOOST_POSE_GRACE_SECONDS: float = 0.50",
):
    assert token in main
print("PASS SERA v209: physical nozzle pivot and RUN pose/grounding stability")
print("Godot Android rendering and real-time touch behavior not verified")
