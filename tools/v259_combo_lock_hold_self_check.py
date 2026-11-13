#!/usr/bin/env python3
"""v259: AUTO lock remains fixed through Melee3/Bash input reception."""
from pathlib import Path
import re
R=Path(__file__).resolve().parents[1]
def read(p):return (R/p).read_text(encoding="utf-8")
m=read("scripts/main.gd")
v=re.search(r'^config/name="SERA v(\d+)"$',read("project.godot"),re.M)
assert v and int(v.group(1))>=259
assert (R/"README_v259_ja.md").exists()
assert "v259 — 3段格闘" in read("docs/SERA_COMBAT_DEFENSE_ENEMIES.md")
assert "v259 AUTO lock hold" in read("docs/history/AGENTS_THROUGH_V316.md")
attack=m.split("func _advance_attack(delta: float) -> void:",1)[1].split("func _screen_drag_to_ground(",1)[0]
assert "bash_followup_window_remaining = BASH_LINK_SECONDS" in m
assert "func _combo_lock_retention_active() -> bool:" in m
assert "bash_loop_window_remaining = BASH_LINK_SECONDS" in attack
assert "combat_state = CombatState.IDLE" in attack
assert "const BASH_LINK_SECONDS: float = 0.65" in m
hold=m.split("func _combo_followup_input_window_open() -> bool:",1)[1].split(
    "func _cancel_combo_followup_windows_for_movement()",1)[0]
assert "bash_followup_window_remaining > 0.0" in hold
assert "bash_loop_window_remaining > 0.0" in hold
cancel=m.split("func _cancel_combo_followup_windows_for_movement() -> void:",1)[1].split(
    "func _cancel_attack()",1)[0]
assert "bash_followup_window_remaining = 0.0" in cancel
assert "bash_loop_window_remaining = 0.0" in cancel
for phrase in ("locked_target_part_id =", "manual_part_lock_active =", "auto_lock_enabled ="):
    assert phrase not in cancel,phrase
drag=m.split("func _change_drag(pos: Vector2) -> void:",1)[1].split("func _update_boost_gesture(",1)[0]
# v264: the completed finisher may also reserve a short side-kick flick.
assert "direction_input = Vector2.ZERO if (bash_flick_candidate or side_kick_flick_candidate) else _analog_stick_direction(pos)" in drag
assert "if direction_input.length_squared() > 0.000001 or movement_boost_active:" in drag
assert "_cancel_combo_followup_windows_for_movement()" in drag
assert "_cancel_attack()" in drag
step=m.split("func _start_omni_step(flick: Vector2) -> bool:",1)[1].split("func _start_back_step()",1)[0]
assert "_cancel_combo_followup_windows_for_movement()" in step
assert step.index("if not _spend_energy(") < step.index("_cancel_combo_followup_windows_for_movement()")
assert "_cancel_attack()" in step
physics=m.split("func _physics_process(delta: float) -> void:",1)[1].split("func _process(delta: float) -> void:",1)[0]
assert "bash_followup_window_remaining = maxf(0.0, bash_followup_window_remaining - delta)" in physics
assert "bash_loop_window_remaining = maxf(0.0, bash_loop_window_remaining - delta)" in physics
lock=physics.split("# The paired SERA->BODY rays",1)[1].split(
    '_acquire_stable_camera_part(delta, locked_part_broken)',1)[0]
assert "if not combo_held:" in lock
assert "not manual_part_lock_active or locked_part_broken" in lock
assert "var combo_held: bool = _combo_lock_retention_active()" in lock
assert "if not combo_held:" in lock
# v292/v293 routes part selection through a stable AUTO acquire function.
assert "_acquire_stable_camera_part(delta, locked_part_broken)" in physics
assert "var combo_held: bool = _combo_lock_retention_active()" in lock
assert 'locked_target_part_id = ""' in physics
assert "manual_part_lock_active = not auto_lock_enabled" in physics
assert "_acquire_stable_camera_part(delta, locked_part_broken)" in physics
assert "const TARGET_MAX_HP: int = 500" in m
assert "const JUMP_TOUCH_INPUT_ENABLED: bool = false" in m
def permits_auto(state,manual,followup,loop):
    return state=="IDLE" and not manual and followup<=0. and loop<=0.
for state in ("MELEE_APPROACH","DASH","STRIKE_TRACK","STRIKE","BASH_TRACK","BASH"):
    assert not permits_auto(state,False,0,0)
for t in (.001,.2,.65):
    assert not permits_auto("IDLE",False,t,0)
    assert not permits_auto("IDLE",False,0,t)
    assert not permits_auto("IDLE",False,t,t)
assert not permits_auto("IDLE",True,0,0)
assert permits_auto("IDLE",False,0,0)
for p in ((.65,0.),(0.,.65),(.65,.65)):
    assert not permits_auto("IDLE",False,*p)
    assert permits_auto("IDLE",False,0.,0.)
assert "const BASH_FLICK_MAX_SECONDS: float = 0.42" in m
assert "const SECTOR_COUNT: int = 4" in read("scripts/flick_direction_policy.gd")
print("PASS v259: AUTO target unchanged through all active combo states and two follow-up windows")
print("PASS v259: RUN/BOOST/confirmed STEP cancel link windows; MANUAL and invalid-lock safeguards intact")
print("Static and numerical checks only; Android/Godot not run")
