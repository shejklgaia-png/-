#!/usr/bin/env python3
"""SERA v289: breakable lock persistence, visible damaged parts and post-Kick_b RUN."""
from pathlib import Path
import math,re

R=Path(__file__).resolve().parents[1]
main=(R/"scripts/main.gd").read_text(encoding="utf-8")
parts=(R/"scripts/target_parts.gd").read_text(encoding="utf-8")
rig=(R/"scripts/sera_rig.gd").read_text(encoding="utf-8")
project=(R/"project.godot").read_text(encoding="utf-8")
assert int(re.search(r'config/name="SERA v(\d+)"',project).group(1))>=289

def section(s,a,b):
    assert a in s and b in s,(a,b)
    return s.split(a,1)[1].split(b,1)[0]

hold=section(main,"func _combo_lock_retention_active() -> bool:","func _cancel_combo_followup_windows_for_movement()")
for name in ("combat_state != CombatState.IDLE","side_kick_active",
             "back_somersault_active","landing_active and landing_from_somersault",
             "_combo_followup_input_window_open()"):
    assert name in hold,name
damage=section(main,"func _apply_target_part_damage(","func _register_strike_hit(")
assert '"apply_part_hit", locked_target_part_id, raw_attack, raw_break' in damage
assert '"trigger_part_hit_fx"' in damage
assert 'locked_target_part_id = ""' not in damage
assert 'part_break_remaining = maxf(part_break_remaining, 1.0)' in damage
assert 'enemy_shooter.call("set_head_destroyed", true)' in damage
volume=section(main,"func _locked_part_hit_volume_available() -> bool:","func _blade_contact(")
assert 'target_parts.call("has_part", locked_target_part_id)' in volume
assert '_combo_lock_retention_active()' in volume
for function,next_function in (
    ("_blade_contact(","_check_strike_contact("),
    ("_check_strike_contact(","_apply_target_part_damage("),
    ("_advance_homing_toward_target(","_check_bash_contact("),
    ("_distance_to_attack_target_surface(","_start_strike("),
):
    block=section(main,"func "+function,"func "+next_function)
    assert "_locked_part_hit_volume_available()" in block,function
phys=section(main,"func _physics_process(delta: float) -> void:","func _process(delta: float) -> void:")
assert 'var combo_held: bool = _combo_lock_retention_active()' in phys
assert 'if not combo_held:' in phys
assert 'not manual_part_lock_active or locked_part_broken' in phys
assert '"select_front_part",' in phys
assert '"" if locked_part_broken else locked_target_part_id' in phys
assert 'target_parts.call("has_part", locked_target_part_id)' in phys
switch=section(main,"func _switch_lock_screen_direction(direction: int) -> void:","func _update_target_marker_projection(")
assert "or _combo_lock_retention_active()" in switch
fx=section(main,"func _advance_hit_fx(delta: float) -> void:","func _input(event: InputEvent)")
assert '"advance_part_hit_fx", delta' in fx
assert '_combo_lock_retention_active()' in fx  # defer boss KO respawn until combo ends

selector=section(parts,"func select_front_part(origin: Vector3, forward: Vector3,","func get_visible_part_ids(")
assert 'get_parent().get_parent() as Node3D' in selector
assert 'var to_center: Vector3 = (enemy_pivot.global_position - origin' in selector
assert 'var straight_depth: float = desired.dot(flat_toward)' in selector
assert 'if straight_depth <= 0.0' in selector
assert 'var score: float = atan2(lateral, straight_depth)' in selector
assert 'best_score + SELECTION_HYSTERESIS_RADIANS' in selector
assert 'core_box.intersects_segment(origin, aim)' in selector

assert parts.count('100.0, 0.12, 0.00, "remain"')==2
assert 'pivot.visible = false' not in parts
assert 'pivot.visible = true' in parts
assert '_set_part_movement_collision(effective_id, true)' in parts
assert 'func has_part(id: String) -> bool:' in parts
assert 'return parts.has(id) and not bool(parts[id]["broken"])' in parts
assert 'func trigger_part_hit_fx(id: String, duration: float) -> void:' in parts
assert 'func advance_part_hit_fx(delta: float) -> void:' in parts
visual=section(parts,"func _set_part_hit_visual(id: String, ratio: float) -> void:","func advance_part_hit_fx(")
for term in ('PART_HIT_DARK_COLOR','mix * 0.78',
             'Color("a92724").lerp(PART_HIT_GLOW_COLOR, mix)',
             'lerpf(0.08, 0.03, mix)','sin((1.0 - mix) * 44.0)',
             'sin((1.0 - mix) * 22.0)'):
    assert term in visual,term
reset=section(parts,"func reset_parts() -> void:","func has_part(")
assert 'part["hit_fx_remaining"] = 0.0' in reset
assert 'pivot.position = part["rest_position"]' in reset
assert '_set_part_hit_visual(id, 0.0)' in reset
for p in ("head","leg_fl","leg_fr","leg_rl","leg_rr"):
    assert ('_add_part("'+p+'"') in parts

kick=section(rig,"func start_back_somersault() -> bool:","func back_somersault_uses_authored_clip()")
finish=section(rig,"func finish_jump(resume_moving: bool, boosting: bool = false) -> void:","func set_combat_paused(")
for code in ('combat_playback = false','combat_paused = false',
             'freeze_attack_pose = false','attack_windup_active = false'):
    assert code in kick and code in finish,code
assert 'jump_playback = true' in kick
assert 'jump_playback = false' in finish
assert 'RUN_CLIP if resume_moving else WAIT_CLIP' in finish
landing=section(main,"func _advance_landing(delta: float) -> void:","func _classify_side_flick(")
assert 'var was_somersault_landing: bool = landing_from_somersault' in landing
assert 'if was_somersault_landing and gesture_active:' in landing
assert 'direction_input = _analog_stick_direction(pointer_location)' in landing
assert '"finish_jump",' in landing
# Hit timings and RUN control still present.
assert 'BACK_SOMERSAULT_LANDING_SECONDS: float = 0.20' in main
assert 'rig.call("set_moving", show_moving_pose, show_boost_pose,' in main
print("V289_LOCK_PARTS_FX_RUN_STATIC_PASS")
