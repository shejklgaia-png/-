#!/usr/bin/env python3
"""Approved Bittaran debug buttons: four exact limbs, actual down; no damage cheat."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
battle=(root/"scripts/bittaran_battle.gd").read_text(encoding="utf-8")
main=(root/"scripts/main.gd").read_text(encoding="utf-8")
manifest=(root/"tools/sera_ci_manifest.txt").read_text(encoding="utf-8")
for text in (
    'const DEBUG_LEG_BUTTONS_ENABLED: bool = true',
    'func _build_debug_leg_buttons() -> void:',
    'func _debug_leg_button_at(position: Vector2) -> String:',
    'func _debug_break_leg(id: String) -> bool:',
    'func _handle_bittaran_leg_break(',
    'func _sync_debug_leg_buttons() -> void:',
    'func _input(event: InputEvent) -> void:',
    'super._input(event)',
    '"leg_fl": "前左 / BREAK"',
    '"leg_fr": "前右 / BREAK"',
    '"leg_rl": "後左 / BREAK"',
    '"leg_rr": "後右 / BREAK"',
    '"apply_part_hit", id, 0.0, raw_break)',
    '_handle_bittaran_leg_break(\n        id, result, active_at_hit, attacking_leg_at_hit)',
):
    assert text in battle,text
assert 'var attacking_leg_at_hit: String = (str(' in battle
assert 'var active_at_hit: bool = (bittaran_rig != null and not str(' in battle
assert 'func _handle_bittaran_leg_break' not in main
assert 'func _debug_break_leg' not in main
assert 'gd tools/bittaran_four_leg_debug_runtime_check.gd' in manifest
assert 'py tools/bittaran_four_leg_debug_self_check.py' in manifest
print("BITTARAN_FOUR_LEG_DEBUG_STATIC_PASS")
