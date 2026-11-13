#!/usr/bin/env python3
"""SERA v317: main combat state wrappers delegate without moving live state."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
policy = (ROOT / "scripts/sera_combat_flow.gd").read_text(encoding="utf-8")
assert 'const COMBAT_FLOW = preload("res://scripts/sera_combat_flow.gd")' in main
for method in (
    "guard_can_start", "followup_window_open", "combo_retains_lock",
    "strike_stage_count", "strike_is_finisher", "active_strike_clip",
    "strike_cancel_time", "melee3_flick_cancel_time", "tracking_slice",
):
    assert f"static func {method}(" in policy
    assert f"COMBAT_FLOW.{method}(" in main
for signature in (
    "func _guard_can_start() -> bool:",
    "func _combo_followup_input_window_open() -> bool:",
    "func _combo_lock_retention_active() -> bool:",
    "func _strike_stage_count() -> int:",
    "func _is_strike_finisher() -> bool:",
    "func _active_strike_clip(stage: int) -> String:",
    "func _strike_cancel_time(stage: int) -> float:",
    "func _melee3_flick_cancel_time() -> float:",
    "func _advance_attack(delta: float) -> void:",
):
    assert signature in main, signature
for text in (
    "combat_state == CombatState.IDLE",
    "rig != null and bool(rig.get(\"loading_ok\"))",
    "combat_state != CombatState.IDLE",
    "landing_active and landing_from_somersault",
    "STRIKE_CLIPS.size()",
    "KATANA_SECOND_STRIKE_CLIP",
    "STRIKE_CANCEL_TIMES",
    "MELEE3_FLICK_CANCEL_DELAY",
):
    assert text in main, text
assert main.count("COMBAT_FLOW.tracking_slice(") == 4
for pattern in (
    'get_tree(', 'get_viewport(', 'FileAccess', 'DisplayServer',
    'Engine.', 'user://', 'HTTPRequest', 'var combat_state:',
):
    assert pattern not in policy, pattern
assert "return 7.0 / 24.0 + delay" in policy
assert "return float(cancel_times[regular_clip_count - 1]) + delay" in policy
assert "maxf(0.0, limit_seconds - elapsed)" in policy
print("SERA_COMBAT_FLOW_STATIC_PASS: delegated combat rules, full state retained")
