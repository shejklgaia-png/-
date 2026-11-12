#!/usr/bin/env python3
"""SERA v269: screenshot-proven screen-right flick behind actor should be a kick."""
from pathlib import Path
import math
import re

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT/"scripts/main.gd").read_text(encoding="utf-8")
project = (ROOT/"project.godot").read_text(encoding="utf-8")
assert 'config/name="SERA v269"' in project

def function(name, next_name):
    return main.split("func "+name, 1)[1].split("func "+next_name, 1)[0]

helper = function("_combo_kick_side_for_flick(flick: Vector2) -> int:", "_step_local_pose_direction")
begin = function("_begin_drag(pos: Vector2) -> void:", "_analog_stick_direction")
drag = function("_change_drag(pos: Vector2) -> void:", "_update_boost_gesture")
release = function("_end_drag(release_pos: Vector2) -> void:", "_remember_jump_flick_sample")
request = function("_request_combo_side_kick(flick: Vector2) -> bool:", "_launch_combo_side_kick")
boost = function("_update_boost_gesture(delta: float) -> void:", "_end_drag")
step = function("_start_omni_step(flick: Vector2) -> bool:", "_start_back_step")
physics = function("_physics_process(delta: float) -> void:", "_process")

# The video (SERA v268, 1000034692.mp4) has multiple STRIKE3 -> STEP
# transitions (1.25s, 5.62s, 10.3s), never KICK QUEUED. At 5.62s and
# 10.3s SERA visually faces the boss to screen-left, while the on-screen
# controller's swipe points sideways right; the actor-sector is BACK.
assert "var actor_sector: int = FLICK_DIRECTION_POLICY.sector_index(" in helper
assert "flick, gesture_screen_forward" in helper
assert "if actor_sector == 1:" in helper and "if actor_sector == 3:" in helper
assert "if actor_sector == 2:" in helper
assert "var screen_sector: int = FLICK_DIRECTION_POLICY.sector_index(" in helper
assert "flick, Vector2.UP" in helper
assert "if screen_sector == 1:" in helper and "if screen_sector == 3:" in helper
assert "return 0" in helper
print("PASS: SERA-lateral kicks + screen-horizontal fallback inside actor-BACK sector")

# Mirror the exact policy function from flick_direction_policy.gd.
def sector(x,y,fx,fy):
    if math.hypot(x,y)<1e-6 or math.hypot(fx,fy)<1e-6:
        return -1
    n=math.hypot(fx,fy); fx/=n; fy/=n
    right=(-fy,fx)
    a=math.atan2(x*right[0]+y*right[1], x*fx+y*fy)
    return math.floor((a+math.pi/4)/(math.pi/2))%4

def kick(x,y,fx,fy):
    actor=sector(x,y,fx,fy)
    if actor==1:return 1
    if actor==3:return -1
    if actor==2:
        screen=sector(x,y,0,-1)
        if screen==1:return 1
        if screen==3:return -1
    return 0

# Observed camera: character faces the boss at SCREEN LEFT.
for dx,dy in [(1,0),(1,.20),(1,-.25),(1,.45)]:
    assert sector(dx,dy,-1,0)==2, "swipe is actor-back in observed side camera"
    assert sector(dx,dy,0,-1)==1, "but right on the controller screen"
    assert kick(dx,dy,-1,0)==1, "video gesture MUST now launch Kick_r"
# Preserve character-relative side kicks when actor facing sideways.
assert kick(0,-1,-1,0)==1
assert kick(0,1,-1,0)==-1
assert kick(0,-1,1,0)==-1
assert kick(0,1,1,0)==1
# When a screen swipe is clearly actor-forward, don't steal Bash.
assert kick(-1,0,-1,0)==0
assert kick(1,0,1,0)==0
# In normal forward-facing screen view both left and right remain exact.
assert kick(1,0,0,-1)==1
assert kick(-1,0,0,-1)==-1
# No face-on screen up/down should be misread as lateral kick.
assert kick(0,-1,0,-1)==0
assert kick(0,1,0,-1)==0
print("PASS: filmed STEP RIGHT/DIAGONAL now Kick_r; Bash/front and actor-relative kicks preserved")

# The release gate and actual launch use EXACTLY the same helper; no
# double-classification regression. Outside combo window, normal STEP
# remains separate and retains the original 360-degree screen vector.
assert "side_kick_flick_candidate = (" in begin
assert "combat_state == CombatState.STRIKE_TRACK" in begin
assert "and bash_followup_window_remaining > 0.0))" in begin
assert "_combo_kick_side_for_flick(kick_flick_direction) != 0" in release
assert "if _request_combo_side_kick(kick_flick_direction):" in release
assert "var side: int = _combo_kick_side_for_flick(flick)" in request
assert re.search(r"\n\s{8}return\s*\n",release.split(
    "if side_kick_requested",1)[1].split("if bash_requested",1)[0])
assert "if _start_omni_step(flick_direction):" in release
assert "var world_step: Vector3 = _screen_drag_to_ground(direction)" in step
assert 'rig.call("start_side_kick", step_kick_side_request, step_duration_current)' in step
print("PASS: lateral flick cannot be reinterpreted as STEP, movement remains screen-relative")

# A queued kick must block BOOST activation until it has been classified;
# previous code only blocked Bash and could drop the kick during a fast drag.
assert "or energy_exhausted or bash_flick_candidate or side_kick_flick_candidate" in boost
assert "direction_input = Vector2.ZERO if (bash_flick_candidate or side_kick_flick_candidate)" in drag
assert "not (bash_flick_candidate or side_kick_flick_candidate)" in physics
assert '"STRIKE 3/3  |  KICK QUEUED"' in physics
assert '"KICK RIGHT  |  Kick_r"' in physics
assert '"KICK LEFT  |  Kick_l"' in physics
print("PASS: reserved flick cannot trigger BOOST or RUN, debug HUD exposes queued and active kick")
print("SERA v269 static/numeric video regression PASS; Godot Android runtime not executed")
