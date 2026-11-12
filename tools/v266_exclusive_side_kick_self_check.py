#!/usr/bin/env python3
"""SERA v266: side-kick follow-up owns lateral flicks exclusively."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
match = re.search(r'config/name="SERA v([0-9]+)"', project)
assert match and int(match.group(1)) >= 266

def body(start: str, end: str) -> str:
    return main.split(start, 1)[1].split(end, 1)[0]

start = body("func _begin_drag(pos: Vector2) -> void:", "func _analog_stick_direction")
change = body("func _change_drag(pos: Vector2) -> void:", "func _update_boost_gesture")
release = body("func _end_drag(release_pos: Vector2) -> void:", "func _remember_jump_flick_sample")
kick = body("func _request_combo_side_kick(flick: Vector2) -> bool:", "func _start_omni_step")

assert "side_kick_flick_candidate = (" in start
assert "and bash_followup_window_remaining > 0.0))" in start
assert "var side_kick_requested: bool = (side_kick_flick_candidate" in release

# No early directional cancellation; fast flicks with a transient diagonal
# must still be classified from the final release displacement.
reservation = change.split("if side_kick_flick_candidate and (", 1)[1].split(
    "side_kick_flick_candidate = false", 1)[0]
assert "BASH_FLICK_MAX_SECONDS" in reservation
assert "sector_index" not in reservation
assert "gesture_max_travel > BASH_FLICK_CANDIDATE_GRACE_PIXELS" not in reservation
assert "direction_input = Vector2.ZERO if (bash_flick_candidate or side_kick_flick_candidate)" in change
print("PASS: fast kick reservation survives intermediate diagonal drag")

exclusive = release.split("if side_kick_requested and kick_flick_direction.length_squared()", 1)[1].split(
    "if bash_requested and _request_combo_bash():", 1)[0]
assert "_combo_kick_side_for_flick(kick_flick_direction) != 0" in exclusive
assert 'if _request_combo_side_kick(kick_flick_direction):' in exclusive
assert re.search(r'\n\s{8}return\s*\n', exclusive), "lateral branch must return unconditionally"
assert exclusive.index("return") > exclusive.index("_request_combo_side_kick(kick_flick_direction)")
assert "if _start_omni_step(flick_direction):" in release.split(
    "if bash_requested and _request_combo_bash():", 1)[1]
print("PASS: lateral kick consumes the entire gesture, even on failed initiation")
print("PASS: other sectors still route to existing Bash and 360-degree STEP")

assert 'if side != 2 and not bool(rig.call("has_side_kick", side)):' in kick
assert "step_kick_side_request = side" in kick
assert "step_kick_side_request = 0" in kick
assert "return started" in kick
assert 'rig.call("start_side_kick", step_kick_side_request, step_duration_current)' in main
assert 'rig.call("start_omni_step", pose_direction)' in main
print("PASS: same STEP movement API but exclusive authored side-kick selection")
print("SERA v266 static regression PASSED; Android touch/runtime not verified.")
