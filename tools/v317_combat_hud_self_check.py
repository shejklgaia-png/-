#!/usr/bin/env python3
"""SERA v317 Stage14: combat HUD priority, exact formats and lazy clip calls."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
formatter = (ROOT / "scripts/sera_combat_hud_text.gd").read_text(encoding="utf-8")
assert 'const COMBAT_HUD_TEXT = preload("res://scripts/sera_combat_hud_text.gd")' in main
assert "extends RefCounted" in formatter
for name in ("guard_label", "somersault_label", "landing_label", "jump_label",
             "step_label", "strike_label", "dash_label", "back_kick_track_label",
             "bash_track_label", "strike_track_label", "boost_label",
             "boost_hold_label", "run_label"):
    assert f"static func {name}(" in formatter, name
    assert f"COMBAT_HUD_TEXT.{name}(" in main, name
for forbidden in ("get_tree(", "get_node(", "get_viewport(", "static var ", ".call(",
                  "FileAccess", "Label.new(", "Array.new(", "Dictionary.new(",
                  "get_script_constant_map("):
    assert forbidden not in formatter, forbidden

def section(start: str, stop: str) -> str:
    assert main.count(start) == 1, start
    return main.split(start, 1)[1].split(stop, 1)[0]

physics = section("func _physics_process(delta: float) -> void:",
                  "func _refresh_combat_state_hud(")
refresh = section("func _refresh_combat_state_hud(", "func _process(delta: float) -> void:")
assert physics.index('rig.call("update_omni_step_direction"') < physics.index(
    "thruster_presentation.update(rig, exhaust_on,") < physics.index(
    "_update_melee_lock_marker()") < physics.index(
    "if not step_active and step_status_label != null:") < physics.index(
    "if floor_stage != null:") < physics.index(
    "_refresh_combat_state_hud(")
assert "running, stepping_this_frame, kick_side_this_frame," in physics
assert "step_flick_this_frame, step_side_this_frame, somersault_this_frame," in physics
assert "landing_this_frame, jumping_this_frame)" in physics
priorities = (
    "if down_remaining > 0.0:",
    'state_label.text = "DOWN / INVULNERABLE"',
    "elif guard_break_remaining > 0.0:",
    'state_label.text = "GUARD BREAK  %d/%d"',
    "elif damage_reaction_active:",
    'state_label.text = "DAMAGE  |  Damageknock"',
    "elif guard_active:",
    "COMBAT_HUD_TEXT.guard_label(",
    "elif back_somersault_active or somersault_this_frame:",
    "COMBAT_HUD_TEXT.somersault_label(",
    "elif landing_this_frame or landing_active:",
    "COMBAT_HUD_TEXT.landing_label(",
    "elif jumping_this_frame and combat_state == CombatState.IDLE and not stepping_this_frame:",
    "COMBAT_HUD_TEXT.jump_label(",
    "elif stepping_this_frame:",
    "COMBAT_HUD_TEXT.step_label(",
    "match combat_state:",
    "CombatState.MELEE_APPROACH:",
    "CombatState.DASH:",
    "CombatState.STRIKE:",
    "CombatState.BACK_KICK_TRACK:",
    "CombatState.BASH_TRACK:",
    "CombatState.STRIKE_TRACK:",
    "CombatState.BASH:",
    "_:",
)
assert [refresh.index(x) for x in priorities] == sorted(refresh.index(x) for x in priorities)
assert "var count: int = _strike_stage_count()" in refresh
assert "if buffered_side_kick_side == 0:" in refresh
assert "clip = _active_strike_clip(strike_index)" in refresh
assert refresh.index("if buffered_side_kick_side == 0:") < refresh.index(
    "clip = _active_strike_clip(strike_index)")
assert "str(rig.call(\"get_boost_dominant_clip\"))" in refresh
assert "str(rig.call(\"get_run_dominant_clip\"))" in refresh
for text in (
    "GUARD HIT  |  Guard_REACTION", "GUARD  |  Guard",
    "KICK BACK  |  Kick_b", "KICK BACK  |  Jump FALLBACK",
    "KICK BACK LAND  |  0.2s", "JUMP LAND  |  Jump",
    "AIR FALL  |  Jump", "JUMP  |  Jump (1.5m)",
    "KICK RIGHT  |  Kick_r", "KICK LEFT  |  Kick_l",
    "STEP FORWARD  |  Frontstep", "STEP BACK  |  Backstep",
    "STEP DIAGONAL  |  BLENDED", "STEP RIGHT  |  Step_R",
    "STEP LEFT  |  Step_L", "STRIKE %d/%d  |  KICK B QUEUED",
    "STRIKE %d/%d  |  KICK QUEUED", "STRIKE %d/%d  |  %s",
    "MELEE BOOST  %.1fm/s  %.2f/%.1fs",
    "KICK BACK TRACK  %.2f / %.2fs", "BASH WINDUP  %.2f / %.2fs",
    "MELEE %d WINDUP  %.2f / %.2fs",
    "BOOST  x1.5  |  %s", "RUN  |  BOOST POSE HOLD  |  %s",
    "RUN  x1.0  |  %s",
):
    assert text in formatter, text
assert formatter.index("if kick_side != 0:") < formatter.index(
    "if step_flick.y < -0.8:") < formatter.index(
    "if step_flick.y > 0.8:") < formatter.index(
    "if absf(step_flick.y) > 0.15:")
assert formatter.index("if queued_kick_side == 2:") < formatter.index(
    "if queued_kick_side != 0:")
print("SERA_COMBAT_HUD_STATIC_PASS")
