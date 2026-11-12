#!/usr/bin/env python3
"""SERA v270 regression: actor-front lateral swipes, exact step/kick branch, live debug."""
from pathlib import Path
import math
import re

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
rig = (ROOT / "scripts/sera_rig.gd").read_text(encoding="utf-8")
version = (ROOT / "project.godot").read_text(encoding="utf-8")
assert 'config/name="SERA v270"' in version

def body(start, end):
    return main.split("func "+start,1)[1].split("func "+end,1)[0]

helper=body("_combo_kick_side_for_flick(flick: Vector2) -> int:","_step_local_pose_direction")
begin=body("_begin_drag(pos: Vector2) -> void:","_analog_stick_direction")
release=body("_end_drag(release_pos: Vector2) -> void:","_remember_jump_flick_sample")
request=body("_request_combo_side_kick(flick: Vector2) -> bool:","_launch_combo_side_kick")
launch=body("_launch_combo_side_kick(flick: Vector2, side: int) -> bool:","_start_omni_step")
movement=body("_start_omni_step(flick: Vector2) -> bool:","_start_back_step")
advance=body("_advance_attack(delta: float) -> void:","_screen_drag_to_ground")
physics=body("_physics_process(delta: float) -> void:","_process")
detail=body("_refresh_step_status_ui() -> void:","_record_kick_debug")
diagnostic=body("_record_kick_debug(message: String) -> void:","_pointer_on_training_test_button")

# In the previous video STRIKE 3/3 -> BASH appeared twice, STRIKE 3/3 ->
# STEP appeared at other times. The v269 "actor BACK only" fallback omitted
# SCREEN-right/left flicks when the actor actually faced that same direction.
assert helper.index("if actor_sector == 1:") < helper.index("var screen_sector:")
assert helper.index("if actor_sector == 3:") < helper.index("var screen_sector:")
assert "if actor_sector == 2:" not in helper
assert "flick, gesture_screen_forward" in helper
assert "flick, Vector2.UP" in helper
assert "if screen_sector == 1:" in helper
assert "if screen_sector == 3:" in helper
assert "_combo_kick_side_for_flick(kick_flick_direction) != 0" in release
assert "var side: int = _combo_kick_side_for_flick(flick)" in request
assert release.index("if side_kick_requested and kick_flick_direction") < release.index(
    "if bash_requested and _request_combo_bash():")
assert re.search(r"\n\s{8}return\s*\n",release.split(
    "if side_kick_requested",1)[1].split("if bash_requested",1)[0])
print("PASS: screen-lateral combo flicks precede Bash and normal STEP")

# Mirrors the actual sector_index and helper. Verify screen-left and
# screen-right across 720 actor headings, including EXACT actor-FRONT,
# actor-BACK and the two actor-SIDE quadrants.
def sector(dx,dy,fx,fy):
    if math.hypot(dx,dy)<1e-6 or math.hypot(fx,fy)<1e-6:return -1
    length=math.hypot(fx,fy);fx/=length;fy/=length
    right=(-fy,fx)
    angle=math.atan2(dx*right[0]+dy*right[1],dx*fx+dy*fy)
    return math.floor((angle+math.pi/4)/(math.pi/2))%4

def side(dx,dy,fx,fy):
    a=sector(dx,dy,fx,fy)
    if a==1:return 1
    if a==3:return -1
    screen=sector(dx,dy,0,-1)
    if screen==1:return 1
    if screen==3:return -1
    return 0

for degree in range(720):
    angle=math.radians(degree*.5)
    fx,fy=math.sin(angle),-math.cos(angle)
    for swipe in ((120,0),(-120,0),(120,35),(-120,-35)):
        assert side(*swipe,fx,fy) in (-1,1),(degree,swipe)
        if sector(*swipe,fx,fy)==1:assert side(*swipe,fx,fy)==1
        if sector(*swipe,fx,fy)==3:assert side(*swipe,fx,fy)==-1
# Old actor-front case now maps to the visible screen-side kick.
assert sector(120,0,1,0)==0 and side(120,0,1,0)==1
assert sector(-120,0,-1,0)==0 and side(-120,0,-1,0)==-1
# Actor-front UP with no screen-side remains Bash; non-combo STEP unchanged.
assert side(0,-120,0,-1)==0
assert "if _start_omni_step(flick_direction):" in release
assert "var world_step: Vector3 = _screen_drag_to_ground(direction)" in movement
print("PASS: 720 character headings, actor-FRONT/BACK/side inputs, screen-relative movement")

# Latching a user-gesture is not enough to debug an unrecognized request.
# Keep touch-start eligibility and display the exact failure gate for 2s in
# the preexisting training status HUD, instead of repeatedly guessing.
assert "kick_touch_started_in_window = side_kick_flick_candidate" in begin
assert "var kick_started_eligible: bool = kick_touch_started_in_window" in release
assert "kick_touch_started_in_window = false" in release
assert "var recent_finisher: bool" in release
assert '"HOLD >0.42s / BOOST"' in release
assert '"TOO SHORT / SLOW"' in release
assert '"WINDOW CLOSED"' in release
assert '"ANGLE"' in release
assert '"CLIP MISSING"' in request
assert '"STATE BLOCKED"' in request
assert '"EN / ACTION BLOCKED"' in launch
assert '"START "' in launch
assert '"QUEUED "' in request
assert "kick_debug_remaining = 2.0" in diagnostic
assert 'kick_debug_text = "KICK: " + message' in diagnostic
assert "step_detail_label.text = kick_debug_text" in detail
assert "kick_debug_remaining = maxf(0.0, kick_debug_remaining - delta)" in physics
assert "last_melee3_finished_ms = Time.get_ticks_msec()" in advance
assert "buffered_side_kick_flick = flick.normalized()" in request
assert 'rig.call("start_side_kick", step_kick_side_request, step_duration_current)' in movement
assert "func start_side_kick(side: int, movement_duration: float) -> bool:" in rig
print("PASS: touch-down, swipe gates, clip/state/EN failures can be diagnosed from screen video")
print("SERA v270 static/numeric regression PASSED; actual Godot Android playback not executed")
