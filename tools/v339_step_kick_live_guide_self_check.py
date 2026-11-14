#!/usr/bin/env python3
"""v339: 0.1m launch; moving RUN/BOOST dial; second kick chases until contact."""
import json
import math
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
game = (root/"scripts/main.gd").read_text(encoding="utf-8")
rig = (root/"scripts/sera_rig.gd").read_text(encoding="utf-8")
guide = (root/"scripts/touch_overlay.gd").read_text(encoding="utf-8")
spec = json.loads((root/"tools/sera_active_specs.json").read_text(encoding="utf-8"))
version = (root/"project.godot").read_text(encoding="utf-8")
assert 'config/name="SERA v339"' in version

assert spec["ordinary_step"]["distance_m"] == 4
assert spec["ordinary_step"]["launch_warp_m"] == 0.1
assert spec["ordinary_step"]["speed_mps"] == 15
assert spec["ordinary_step"]["launch_fx_s"] == 0.05
assert spec["side_kick"]["distance_m"] == 3
assert spec["side_kick"]["speed_mps"] == 10
assert "const STEP_LAUNCH_WARP_DISTANCE: float = 0.1" in game
assert "launch_distance / maxf(step_arc_length, 0.0001)" in game

update = game.split("func _update_controller_flick_guide(delta: float) -> void:", 1)[1].split(
    "func _desired_camera_follow_focus_xz(", 1)[0]
assert "var live_locomotion: bool = gesture_active and not guard_active" in update
assert "not bash_flick_candidate" in update
assert "not side_kick_flick_candidate" in update
assert "not step_active" in update
assert "(movement_boost_active or direction_input.length_squared() > 0.000001)" in update
assert 'gesture_screen_forward = _touch_to_lock_forward(pointer_origin)' in update
assert update.index("gesture_screen_forward = _touch_to_lock_forward(pointer_origin)") < update.index(
    'touch_ui.call("set_flick_sector_forward", forward, delta, true)')
assert 'return INPUT_GESTURES.combo_kick_side(flick, gesture_screen_forward)' in game
assert 'touch_ui.call("set_flick_sector_forward", gesture_screen_forward, 0.0, true)' in game
assert "flick_sector_forward = result" in guide
assert "if dragging or combo_visible:" in guide
# A combo must not be retargeted while a protected flick is under way.
assert "gesture_screen_forward =" not in game.split(
    "func _change_drag(pos: Vector2) -> void:", 1)[1].split(
    "func _update_boost_gesture(", 1)[0]

kick = game.split("func _advance_side_step(delta: float) -> void:", 1)[1].split(
    "func _move_player_swept(", 1)[0]
assert "var previous_seconds: float = step_duration_current * previous_progress" in kick
assert "_advance_homing_toward_target(chase_dt, BASH_REACH)" in kick
assert "var second_chase_start: float = maxf(" in kick
assert "previous_seconds, step_duration_current * second_windup" in kick
assert "var second_chase_end: float = minf(" in kick
assert "step_elapsed, step_duration_current * second_hit" in kick
assert "_advance_homing_toward_target(second_chase_dt, SIDE_KICK_REACH)" in kick
assert "step_start_offset = actual_radial.rotated(" in kick
assert "if progress >= second_hit:" in kick
assert kick.index("_advance_homing_toward_target(second_chase_dt, SIDE_KICK_REACH)") < kick.index(
    "if progress >= second_hit:")
assert kick.index("if progress >= second_hit:") < kick.index("if side_kick_linear_active:")
assert "step_elapsed = minf(step_duration_current, step_elapsed + delta)" in kick
assert "side_kick_linear_direction * side_kick_linear_distance * line_progress" in kick
assert "for i in range(SIDE_KICK_HIT_PROGRESS.size()):" in kick
assert "const SIDE_KICK_HIT_PROGRESS = [0.25, 0.58333]" in game
assert "const SIDE_KICK_MOTION_TIME_MULTIPLIER: float = 2.0" in game
assert 'side_kick_playback_scale = maxf(0.001, float(animations[chosen]["length"])) / maxf(movement_duration, 0.01)' in rig

# Exact intersection of a frame with the second strike's chase window:
# no pre-windup or post-impact chase, including large physics-frame jumps.
def chase_slice(t0, t1, duration, windup, hit=0.58333):
    return max(0.0, min(t1, duration * hit) - max(t0, duration * windup))

for windup in (0.33333, 0.41667):
    total = 0.6  # same unchanged authored 2x kick duration
    assert chase_slice(0.0, 0.1, total, windup) == 0.0
    assert chase_slice(0.4, 0.6, total, windup) == 0.0
    assert math.isclose(chase_slice(0.0, 0.6, total, windup),
                        total * (0.58333-windup))
    # Chopping a timeline into uneven physics ticks must preserve total time.
    timestamps = (0.0, .07, .11, .18, .29, .36, .48, .6)
    pieces = sum(chase_slice(a,b,total,windup)
                 for a,b in zip(timestamps[:-1],timestamps[1:]))
    assert math.isclose(pieces,total*(0.58333-windup))
print("PASS v339 warp 0.1m, live RUN/BOOST compass, 2nd kick homing through hit")
