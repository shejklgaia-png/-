#!/usr/bin/env python3
"""SERA v274: Kick_b screen-down combo, 4m airborne somersault, 0.2s landing."""
from pathlib import Path
import re
import json

root = Path(__file__).resolve().parents[1]
game = (root/"scripts/main.gd").read_text(encoding="utf-8")
rig = (root/"scripts/sera_rig.gd").read_text(encoding="utf-8")
source = json.loads((root/"assets/sera_source.json").read_text(encoding="utf-8"))
project = (root/"project.godot").read_text(encoding="utf-8")
assert re.search(r'config/name="SERA v\d+"', project)

def segment(text, a, b):
    return text.split("func "+a, 1)[1].split("func "+b, 1)[0]

direction = segment(game, "_combo_kick_side_for_flick(flick: Vector2) -> int:", "_step_local_pose_direction")
release = segment(game, "_end_drag(release_pos: Vector2) -> void:", "_remember_jump_flick_sample")
request = segment(game, "_request_combo_side_kick(flick: Vector2) -> bool:", "_launch_combo_side_kick")
launch = segment(game, "_launch_combo_side_kick(flick: Vector2, side: int) -> bool:", "_start_back_somersault")
start = segment(game, "_start_back_somersault() -> bool:", "_advance_back_somersault")
advance = segment(game, "_advance_back_somersault(delta: float) -> void:", "_cancel_back_somersault")
cancel = segment(game, "_cancel_back_somersault() -> void:", "_start_omni_step")
finish = segment(game, "_advance_attack(delta: float) -> void:", "_screen_drag_to_ground")
land = segment(game, "_advance_landing(delta: float) -> void:", "_classify_side_flick")
physics = segment(game, "_physics_process(delta: float) -> void:", "_process")
begin = segment(game, "_begin_drag(pos: Vector2) -> void:", "_analog_stick_direction")
rig_start = segment(rig, "start_back_somersault() -> bool:", "back_somersault_uses_authored_clip")
rig_progress = segment(rig, "set_back_somersault_progress(progress: float) -> void:", "start_jump")
rig_land = segment(rig, "start_landing(from_back_somersault: bool = false) -> void:", "set_landing_progress")

# Controller direction is SCREEN-relative; DOWN takes precedence within the
# already-latched 3rd-strike combo window, and is never ordinary back-STEP.
assert 'flick, Vector2.UP' in direction
assert "2:" in direction
assert "return 2" in direction
assert "flick, Vector2.UP" in direction and "gesture_screen_forward" not in direction
assert "1:" in direction and "3:" in direction
assert 'side_kick_flick_candidate = (' in begin
assert "and strike_index == STRIKE_CLIPS.size() - 1)" in begin
assert "_combo_kick_side_for_flick(kick_flick_direction) != 0" in release
assert release.index("if side_kick_requested and kick_flick_direction") < release.index("if bash_requested")
assert "if side != 2 and not bool(rig.call(\"has_side_kick\", side)):" in request
assert "buffered_side_kick_side = side" in request
assert "if side == 2:" in launch and "_start_back_somersault()" in launch
handoff = segment(game, "_finish_strike_and_release_queued_kick() -> void:", "_advance_attack")
assert "committed_kick_side = buffered_side_kick_side" in handoff
assert "_launch_combo_side_kick(committed_kick_flick, committed_kick_side)" in handoff
assert "_melee3_flick_cancel_time()" in finish
print("PASS: third strike queues DOWN kick and consumes it before Bash or STEP")

# Dedicated 4m airborne physical motion and one impact; NEVER fake a STEP.
assert "BACK_SOMERSAULT_DISTANCE: float = 4.0" in game
assert "BACK_SOMERSAULT_HEIGHT: float = 1.5" in game
assert "BACK_SOMERSAULT_FLIGHT_SECONDS: float = 0.80" in game
assert "BACK_SOMERSAULT_LANDING_SECONDS: float = 0.20" in game
assert "combat_state != CombatState.IDLE" in start
assert 'rig.call("start_back_somersault")' in start
assert "back_somersault_direction = player.global_position - target.global_position" in start
assert "_move_player_swept(Vector3(arc_delta.x, 0.0, arc_delta.z), true)" in advance
assert "_back_somersault_arc_offset(progress)" in advance
assert "_back_somersault_arc_offset(previous)" in advance
assert "player.move_and_collide(Vector3.UP * vertical_delta)" in advance
assert "rig.rotation.x = angle" in advance
assert "BACK_SOMERSAULT_VISUAL_PIVOT_HEIGHT * (1.0 - cos(angle))" in advance
assert "_register_side_kick_hit()" in advance
assert "_begin_landing(true)" in advance
assert 'rig.call("finish_jump", false, false)' in cancel
print("PASS: 4m swept back arc, 1.5m ascent, actual pose flip, single foot hit")

# Missing authored Kick_b is NOT misreported as a valid Blockbench clip.
# Once an updated original clip is integrated, rig should use it automatically.
assert 'const BACK_SOMERSAULT_CLIP: String = "Kick_b"' in rig
assert "_usable_side_kick_clip(BACK_SOMERSAULT_CLIP)" in rig
assert "somersault_authored = has_back_somersault_clip()" in rig_start
assert '"start_back_somersault"' in game
assert '"back_somersault_uses_authored_clip"' in game
assert "BACK_SOMERSAULT_CLIP if somersault_authored else JUMP_CLIP" in rig_start
assert "set_jump_progress(fraction)" in rig_progress
assert 'somersault_authored = false' in rig_land
assert "var angle: float = TAU * progress" in advance
assert "rig.rotation.x = angle" in advance
assert "if not back_somersault_has_authored_clip and back_somersault_launched:" in advance
assert "Kick_b" in {a["name"] for a in source["animations"]}
print("PASS: use actual Kick_b when available, otherwise existing Jump-pose fallback")

# Only Kick_b changes landing from ordinary 0.125+0.60 to 0.20+0.00.
assert "landing_from_somersault = from_back_somersault" in game
assert "BACK_SOMERSAULT_LANDING_SECONDS" in land
assert "JUMP_LANDING_MOTION_SECONDS" in land
assert "0.0 if landing_from_somersault else JUMP_LANDING_HOLD_SECONDS" in land
assert 'rig.call("set_landing_progress", landing_fraction)' in land
assert 'rig.call("finish_jump"' in land
assert "if back_somersault_active:" in physics
assert "_advance_back_somersault(delta)" in physics
assert '"KICK BACK  |  Kick_b"' in physics
assert '"KICK BACK LAND  |  0.2s"' in physics
assert 'if back_somersault_active:' in segment(game, "_begin_damage_reaction(incoming_direction: Vector3) -> void:", "_advance_damage_knockback")
assert '_cancel_back_somersault()' in segment(game, "_begin_training_ko() -> void:", "_tick_training_ko")
print("PASS: exact 0.20s authored landing, action lock, damage/KO cancellation")
print("v274 STATIC PASS; real Godot action runtime checked separately")
