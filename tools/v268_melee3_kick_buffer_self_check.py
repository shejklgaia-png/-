#!/usr/bin/env python3
"""SERA v268 regression: video-confirmed third-strike premature STEP -> queued kick."""
from pathlib import Path
import json
import re

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
rig = (root / "scripts/sera_rig.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
source = json.loads((root / "assets/sera_source.json").read_text(encoding="utf-8"))
assert (ver := re.search(r'config/name="SERA v([0-9]+)"', project)) and int(ver.group(1)) >= 268

def body(begin, end):
    return main.split("func "+begin, 1)[1].split("func "+end, 1)[0]

start = body("_begin_drag(pos: Vector2) -> void:", "_analog_stick_direction")
change = body("_change_drag(pos: Vector2) -> void:", "_update_boost_gesture")
release = body("_end_drag(release_pos: Vector2) -> void:", "_remember_jump_flick_sample")
classify_step = body("_classify_step_flick(displacement: Vector2, seconds: float) -> Vector2:", "_classify_combo_kick_flick")
classify_kick = body("_classify_combo_kick_flick(displacement: Vector2, seconds: float) -> Vector2:", "_step_local_pose_direction")
request = body("_request_combo_side_kick(flick: Vector2) -> bool:", "_launch_combo_side_kick")
launch = body("_launch_combo_side_kick(flick: Vector2, side: int) -> bool:", "_start_omni_step")
step = body("_start_omni_step(flick: Vector2) -> bool:", "_start_back_step")
advance = body("_advance_attack(delta: float) -> void:", "_screen_drag_to_ground")
cancel = body("_cancel_attack() -> void:", "_request_combo_bash")
bash_request = body("_request_combo_bash() -> bool:", "_start_bash")
bash_start = body("_start_bash() -> void:", "_launch_bash_after_tracking")
strike = body("_start_strike(stage: int = 0) -> void:", "_launch_followup_strike")
physics = body("_physics_process(delta: float) -> void:", "_process")
step_hud = body("_refresh_step_status_ui() -> void:", "_pointer_on_training_test_button")

# The video shows STRIKE 3/3 -> STEP DIAGONAL while Melee3 is not done
# at about 9.60 -> 9.76 and again around 14.24 -> 14.40. Touch-down during
# STRIKE / STRIKE_TRACK 3 is now a kick candidate, not a premature STEP.
assert "((combat_state == CombatState.STRIKE or combat_state == CombatState.STRIKE_TRACK)" in start
assert "and _is_strike_finisher())" in start
assert "or (combat_state == CombatState.IDLE and bash_followup_window_remaining > 0.0))" in start
assert "gesture_screen_forward = FLICK_DIRECTION_POLICY.projected_forward(camera, player)" in start
assert "direction_input = Vector2.ZERO if (bash_flick_candidate or side_kick_flick_candidate)" in change
assert "not (bash_flick_candidate or side_kick_flick_candidate)" in change
assert "not (bash_flick_candidate or side_kick_flick_candidate)" in physics
print("PASS: touch while STRIKE 3/3 stays queued instead of canceling into RUN/STEP")

# The kick's timing matches human-operated Bash and the usual 90-degree
# SERA-side sectors, but its world displacement and STEP remain screen-based.
assert "STEP_FLICK_MAX_SECONDS" in classify_step
assert "BASH_FLICK_MAX_SECONDS" in classify_kick
assert "BASH_FLICK_MIN_FORWARD_PIXELS" in classify_kick
assert "BASH_FLICK_MIN_FORWARD_SPEED" in classify_kick
assert "BASH_FLICK_REVERSAL_RATIO" in classify_kick
assert "BASH_FLICK_MAX_SECONDS" in change.split("if side_kick_flick_candidate and (",1)[1].split(
    "side_kick_flick_candidate = false",1)[0]
assert "kick_flick_direction: Vector2" in release
assert "_combo_kick_side_for_flick(kick_flick_direction) != 0" in release
assert "_request_combo_side_kick(kick_flick_direction)" in release
assert "if _start_omni_step(flick_direction):" in release
assert release.index("if side_kick_requested and kick_flick_direction") < release.index(
    "if bash_requested and _request_combo_bash()")
assert re.search(r"\n\s{8}return\s*\n",release.split(
    "if side_kick_requested",1)[1].split("if bash_requested",1)[0])
print("PASS: valid side-kick swipe never falls through to ordinary STEP")

# Input release during STRIKE 3 stores side + raw screen travel vector.
assert "var side: int = _combo_kick_side_for_flick(flick)" in request
assert "combat_state == CombatState.STRIKE_TRACK" in request
assert "buffered_side_kick_flick = flick.normalized()" in request
assert "buffered_side_kick_side = side" in request
assert "bash_queued = false" in request
assert "_launch_combo_side_kick(flick, side)" in request
assert "step_kick_side_request = side" in launch
assert "var started: bool = _start_omni_step(flick)" in launch
assert "var world_step: Vector3 = _screen_drag_to_ground(direction)" in step
assert 'rig.call("start_side_kick", step_kick_side_request, step_duration_current)' in step

# v283: kick is queued through the authored strike-through key (0.625s),
# then dispatched at 0.675s. No queue means full 0.83333s Melee3 and
# unchanged first-strike availability, with normal idle cleanup at clip end.
handoff = body("_finish_strike_and_release_queued_kick() -> void:", "_advance_attack")
assert "MELEE3_FLICK_CANCEL_DELAY: float = 0.05" in main
assert "float(rig.call(\"get_clip_time\")) >= _melee3_flick_cancel_time()" in advance
assert "and (bash_queued or buffered_side_kick_side != 0)" in advance
assert "if rig.call(\"clip_finished\", _active_strike_clip(strike_index)):" in advance
assert "committed_kick_flick = buffered_side_kick_flick" in handoff
assert "committed_kick_side = buffered_side_kick_side" in handoff
assert "buffered_side_kick_flick = Vector2.ZERO" in handoff
assert "rig.call(\"finish_attack\", false, jump_active and not damage_reaction_active)" in handoff
assert "if committed_kick_side != 0" in handoff
assert "_launch_combo_side_kick(committed_kick_flick, committed_kick_side)" in handoff
assert handoff.index("rig.call(\"finish_attack\", false, jump_active") < handoff.index(
    "_launch_combo_side_kick(committed_kick_flick, committed_kick_side)")
assert "buffered_side_kick_side = 0" in cancel
assert "buffered_side_kick_side = 0" in bash_start
assert "buffered_side_kick_side = 0" in bash_request
assert "buffered_side_kick_side = 0" in strike
print("PASS: v284 0.05s post-swing cancel for queued kicks; full unqueued clip and cleanup")

# Render current behavior explicitly in the same debug HUD the user recorded.
hud = (Path(__file__).resolve().parents[1] / "scripts/sera_combat_hud_text.gd").read_text(encoding="utf-8")
assert '"STRIKE %d/%d  |  KICK QUEUED"' in hud
assert '"KICK RIGHT  |  Kick_r"' in hud
assert '"KICK LEFT  |  Kick_l"' in hud
assert "COMBAT_HUD_TEXT.strike_label(" in physics
assert "COMBAT_HUD_TEXT.step_label(" in physics
assert '"KICK %s %.2fm planned"' in step_hud
assert '"STEP DIAGONAL  |  BLENDED"' in physics

clips={a["name"]:a for a in source["animations"]}
for name in ("Melee3","Kick_l","Kick_r"):
    assert name in clips
assert float(clips["Melee3"]["length"]) > 0.6
assert all(float(clips[name]["length"]) == 1.0 for name in ("Kick_l","Kick_r"))
assert "func start_side_kick(side: int, movement_duration: float) -> bool:" in rig
print("PASS: genuine authored strike + both kicks present; debug distinguishes STEP/KICK")
print("SERA v268 regression PASSED (code and clip data only; Godot Android not executed)")
