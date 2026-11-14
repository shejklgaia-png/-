#!/usr/bin/env python3
"""v284: Melee3 queued flicks cancel 0.05s after swing; first tap unchanged."""
from pathlib import Path
import json, re

root=Path(__file__).resolve().parents[1]
main=(root/"scripts/main.gd").read_text(encoding="utf-8")
flow=(root/"scripts/sera_combat_flow.gd").read_text(encoding="utf-8")
rig=(root/"scripts/sera_rig.gd").read_text(encoding="utf-8")
source=json.loads((root/"assets/sera_source.json").read_text(encoding="utf-8"))
project=(root/"project.godot").read_text(encoding="utf-8")
assert int(re.search(r'config/name="SERA v(\d+)"',project).group(1))>=283
assert "const STRIKE_CANCEL_TIMES = [7.0 / 24.0, 7.0 / 24.0, 15.0 / 24.0]" in main
assert "const MELEE3_FLICK_CANCEL_DELAY: float = 0.05" in main
melee3=next(a for a in source["animations"] if a["name"]=="Melee3")
assert abs(float(melee3["length"])-0.83333)<0.0001
assert 15.0 / 24.0 + 0.05 < float(melee3["length"])
cancel=main.split("func _melee3_flick_cancel_time() -> float:",1)[1].split(
    "func _start_strike(",1)[0]
assert "COMBAT_FLOW.melee3_flick_cancel_time(" in cancel
assert "_katana_equipped(), STRIKE_CANCEL_TIMES," in cancel
assert "STRIKE_CLIPS.size(), MELEE3_FLICK_CANCEL_DELAY)" in cancel
assert "if katana:" in flow
assert "7.0 / 24.0 + delay" in flow
assert "return float(cancel_times[regular_clip_count - 1]) + delay" in flow
advance=main.split("func _advance_attack(delta: float) -> void:",1)[1].split(
    "func _screen_drag_to_ground(",1)[0]
assert "float(rig.call(\"get_clip_time\")) >= _melee3_flick_cancel_time()" in advance
assert "and (bash_queued or buffered_side_kick_side != 0)" in advance
assert advance.index("_melee3_flick_cancel_time()")<advance.index(
    "if rig.call(\"clip_finished\", _active_strike_clip(strike_index)):")
assert "if bash_queued:" in advance and "_start_bash()" in advance
assert "_finish_strike_and_release_queued_kick()" in advance
assert "_strike_cancel_time(strike_index)" in advance  # stages 1, 2 unchanged
handoff=main.split("func _finish_strike_and_release_queued_kick() -> void:",1)[1].split(
    "func _advance_attack(",1)[0]
assert "committed_kick_flick = buffered_side_kick_flick" in handoff
assert "committed_kick_side = buffered_side_kick_side" in handoff
assert 'rig.call("finish_attack", false, jump_active and not damage_reaction_active)' in handoff
assert "_launch_combo_side_kick(committed_kick_flick, committed_kick_side," in handoff
assert "buffered_side_kick_side = 0" in handoff
first=main.split("func _start_attack() -> bool:",1)[1].split(
    "func _combo_followup_input_window_open(",1)[0]
assert "if combat_state == CombatState.STRIKE:" in first
assert "if strike_index < _strike_stage_count() - 1:" in first
assert "return false" in first
assert "if combat_state != CombatState.IDLE:" in first
assert "bash_loop_window_remaining > 0.0" in first
assert "bash_followup_window_remaining = BASH_LINK_SECONDS" in handoff
begin=main.split("func _begin_drag(pos: Vector2) -> void:",1)[1].split(
    "func _analog_stick_direction(",1)[0]
bash=main.split("func _request_combo_bash() -> bool:",1)[1].split(
    "func _start_bash(",1)[0]
assert "combat_state == CombatState.STRIKE_TRACK" in begin
assert "combat_state == CombatState.STRIKE_TRACK" in bash
assert "bash_queued = true" in bash
print("V283_MELEE3_FLICK_CANCEL_STATIC_PASS")
