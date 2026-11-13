#!/usr/bin/env python3
"""SERA v317 Stage 5: live BOOST state stays in main, pure rules are delegated."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
policy = (root / "scripts/sera_boost_state.gd").read_text(encoding="utf-8")
assert 'const BOOST_STATE = preload("res://scripts/sera_boost_state.gd")' in main
for method in ("next_gesture_state", "reset_speed_state", "next_speed_state"):
    assert f"static func {method}(" in policy
    assert f"BOOST_STATE.{method}(" in main
for method in ("_update_boost_gesture(delta: float)", "_update_boost_speed(delta: float)",
               "_reset_boost_speed_transition()"):
    assert f"func {method} -> void:" in main
gesture = main.split("func _update_boost_gesture(delta: float) -> void:", 1)[1].split(
    "func _end_drag(", 1)[0]
for token in (
    "if not gesture_active or guard_active or damage_reaction_active",
    "or energy_exhausted or bash_flick_candidate or side_kick_flick_candidate",
    "or jump_active or landing_active or back_somersault_active:",
    "boost_confirm_elapsed = 0.0",
    "touch_ui.call(\"set_movement_boost\", false)",
    "BOOST_STATE.next_gesture_state(",
    "DRAG_RADIUS, BOOST_START_RADIUS_RATIO, BOOST_EXIT_RADIUS_RATIO,",
    "BOOST_CONFIRM_SECONDS)",
    "boost_has_activated_this_gesture = true",
    "touch_ui.call(\"set_movement_boost\", movement_boost_active)",
):
    assert token in gesture, token
for token in (
    "if finger_distance < drag_radius * exit_ratio:",
    "elif finger_distance >= drag_radius * start_ratio:",
    "next_confirmation += maxf(delta, 0.0)",
    "if next_confirmation >= confirm_seconds:",
    "next_confirmation = 0.0",
    "if not is_equal_approx(wanted, next_target):",
    "next_start = current_multiplier",
    "next_elapsed = 0.0",
    "next_elapsed = minf(blend_seconds, next_elapsed + maxf(delta, 0.0))",
    "var eased: float = t * t * (3.0 - 2.0 * t)",
    '"multiplier": lerpf(next_start, next_target, eased)',
):
    assert token in policy, token
for token in (
    "var boost_speed_multiplier: float = 1.0",
    "var boost_speed_transition_start: float = 1.0",
    "var boost_speed_transition_target: float = 1.0",
    "var boost_speed_transition_elapsed: float = BOOST_SPEED_BLEND_SECONDS",
    "const BOOST_SPEED_BLEND_SECONDS: float = 0.20",
):
    assert token in main, token
for forbidden in ("get_tree(", "get_viewport(", "touch_ui", "part_stats", "var movement_boost_active:",
                  "var boost_speed_multiplier:", "FileAccess", "DisplayServer"):
    assert forbidden not in policy, forbidden
print("SERA_BOOST_STATE_STATIC_PASS")
