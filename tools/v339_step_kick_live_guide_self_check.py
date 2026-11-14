#!/usr/bin/env python3
"""Historical v339 warp 0.1m, live RUN/BOOST dial, second kick pursuit."""
from pathlib import Path
import json,math
r=Path(__file__).resolve().parents[1]
m=(r/"scripts/main.gd").read_text()
rig=(r/"scripts/sera_rig.gd").read_text()
ui=(r/"scripts/touch_overlay.gd").read_text()
spec=json.loads((r/"tools/sera_active_specs.json").read_text())
assert 'config/name="SERA v342"' in (r/"project.godot").read_text()
assert spec["ordinary_step"]["distance_m"]==4
assert spec["ordinary_step"]["launch_warp_m"]==.1
assert spec["ordinary_step"]["speed_mps"]==15
assert spec["ordinary_step"]["launch_fx_s"]==.05
assert spec["side_kick"]["distance_m"]==4
assert spec["side_kick"]["duration_reference_distance_m"]==3
assert "const STEP_LAUNCH_WARP_DISTANCE: float = 0.1" in m
guide=m.split("func _update_controller_flick_guide(delta: float) -> void:",1)[1].split("func _desired_camera_follow_focus_xz(",1)[0]
for token in ("var live_locomotion: bool = gesture_active",
    "movement_boost_active or direction_input.length_squared() > 0.000001",
    "gesture_screen_forward = _touch_to_lock_forward(pointer_origin)",
    'touch_ui.call("set_flick_sector_forward", forward, delta, true)'):
    assert token in guide,token
assert 'return INPUT_GESTURES.combo_kick_side(flick, gesture_screen_forward)' in m
assert 'touch_ui.call("set_flick_sector_forward", gesture_screen_forward, 0.0, true)' in m
assert "flick_sector_forward = result" in ui
kick=m.split("func _advance_side_step(delta: float) -> void:",1)[1].split("func _move_player_swept(",1)[0]
for token in ("var previous_seconds: float = step_duration_current * previous_progress",
              "_advance_homing_toward_target(chase_dt, BASH_REACH)",
              "previous_seconds, step_duration_current * second_windup",
              "step_elapsed, step_duration_current * second_hit",
              "_advance_homing_toward_target(second_chase_dt, SIDE_KICK_REACH)",
              "side_kick_linear_start_elapsed = step_elapsed",
              "side_kick_linear_direction * side_kick_linear_distance * line_progress"):
    assert token in kick,token
assert "step_signed_angle * orbit_progress" not in kick
assert "const SIDE_KICK_HIT_PROGRESS = [0.25, 0.58333]" in m
assert "const SIDE_KICK_MOTION_TIME_MULTIPLIER: float = 8.0 / 3.0" in m
assert 'side_kick_playback_scale = maxf(0.001, float(animations[chosen]["length"])) / maxf(movement_duration, 0.01)' in rig
def chase_slice(t0,t1,d,w,hit=.58333):
    return max(0.,min(t1,d*hit)-max(t0,d*w))
for w in (.33333,.41667):
    d=.8
    ticks=(0.,.07,.11,.18,.29,.36,.48,.60,.70,.8)
    actual=sum(chase_slice(a,b,d,w) for a,b in zip(ticks[:-1],ticks[1:]))
    assert math.isclose(actual,d*(.58333-w))
print("PASS v339 warp/compass/locked contact, v340 straight 4m exit")
