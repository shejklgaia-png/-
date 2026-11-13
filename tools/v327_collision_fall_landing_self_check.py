#!/usr/bin/env python3
"""SERA v327: enemy solid collisions own XZ only, landing soles are planted."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
main = (root/"scripts/main.gd").read_text(encoding="utf-8")
rig = (root/"scripts/sera_rig.gd").read_text(encoding="utf-8")
equipment = (root/"scripts/sera_equipment.gd").read_text(encoding="utf-8")
physics = main.split("func _physics_process(delta: float) -> void:",1)[1].split(
    "func _refresh_combat_state_hud(",1)[0]
sweep = main.split("func _move_player_swept(",1)[1].split("func _debug_jump(",1)[0]
assert 'target_collider.position.y = TARGET_BASE_HEIGHT - target.position.y' in physics
assert 'player.position.y = fixed_y' in sweep and 'remainder.y = 0.0' in sweep
assert 'func _resolve_passive_vertical_motion(' in main
assert 'passive_fall_velocity + JUMP_GRAVITY * maxf(delta, 0.0)' in main
assert 'player.position.y - passive_fall_velocity * maxf(delta, 0.0)' in main
assert '_resolve_passive_vertical_motion(delta, before_slide_y,' in physics
assert 'or stepping_this_frame or combat_state != CombatState.IDLE)' in physics
assert 'player.position.y = wanted_y' in main.split("func _advance_back_somersault(",1)[1]
assert 'player.position.y = 0.0' in main.split("func _advance_back_somersault(",1)[1]
assert 'landing_pose_active = true' in rig
assert 'equipment_handler.call("snap_grounded_sole_to_floor", true)' in rig
assert 'func snap_grounded_sole_to_floor(allow_landing: bool = false)' in equipment
assert 'bool(rig.get("jump_playback")) and not allow_landing' in equipment
assert 'config/name="SERA v327"' in (root/"project.godot").read_text(encoding="utf-8")
print("PASS v327 collision XZ, passive fall, authored Kick_b landing feet")
