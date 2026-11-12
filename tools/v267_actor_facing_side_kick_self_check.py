#!/usr/bin/env python3
"""SERA v267: actor-relative 90-degree kicks, independent screen movement."""
from pathlib import Path
import math
import re

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
policy = (root / "scripts/flick_direction_policy.gd").read_text(encoding="utf-8")
version = (root / "project.godot").read_text(encoding="utf-8")
assert (m := re.search(r'config/name="SERA v([0-9]+)"', version))
assert int(m.group(1)) >= 267

def func(name, next_name):
    return main.split("func " + name, 1)[1].split("func " + next_name, 1)[0]

begin = func("_begin_drag(pos: Vector2) -> void:", "_analog_stick_direction")
change = func("_change_drag(pos: Vector2) -> void:", "_update_boost_gesture")
end = func("_end_drag(release_pos: Vector2) -> void:", "_remember_jump_flick_sample")
request = func("_request_combo_side_kick(flick: Vector2) -> bool:", "_start_omni_step")
step = func("_start_omni_step(flick: Vector2) -> bool:", "_start_back_step")
move = func("_screen_drag_to_ground(screen_drag: Vector2) -> Vector3:", "_reset_boost_speed_transition")

assert "gesture_screen_forward = FLICK_DIRECTION_POLICY.projected_forward(camera, player)" in begin
assert "side_kick_flick_candidate = (" in begin
assert "and bash_followup_window_remaining > 0.0))" in begin
assert "_combo_kick_side_for_flick(kick_flick_direction) != 0" in end
helper = func("_combo_kick_side_for_flick(flick: Vector2) -> int:", "_step_local_pose_direction")
assert "flick, gesture_screen_forward" in helper
assert "if actor_sector == 1:" in helper and "if actor_sector == 3:" in helper
assert "var side: int = _combo_kick_side_for_flick(flick)" in request
assert "Vector2.UP" not in end.split("if side_kick_requested",1)[1].split("if bash_requested",1)[0]
assert "Vector2.UP" not in request
candidate = change.split("if side_kick_flick_candidate and (",1)[1].split(
    "direction_input =",1)[0]
assert "BASH_FLICK_MAX_SECONDS" in candidate
assert "sector_index" not in candidate
assert "if _request_combo_side_kick(kick_flick_direction):" in end
assert re.search(r"\n\s{8}return\s*\n", end.split(
    "if side_kick_requested",1)[1].split("if bash_requested",1)[0])
print("PASS: both kick routing sites use the touch-start SERA-facing screen axis")

# Unchanged continuous input path and STEP travel are SCREEN-space.
assert "var displacement: Vector2 = pos - pointer_origin" in func(
    "_analog_stick_direction(pos: Vector2) -> Vector2:", "_change_drag")
assert "FLICK_DIRECTION_POLICY.screen_step_direction(displacement)" in main
assert "var direction: Vector2 = flick.normalized()" in step
assert "var world_step: Vector3 = _screen_drag_to_ground(direction)" in step
assert "var pose_direction: Vector2 = _step_local_pose_direction(world_step)" in step
assert "var screen_right: Vector3 = camera.global_transform.basis.x" in move
assert "var screen_forward: Vector3 = -camera.global_transform.basis.z" in move
assert "direction_input = Vector2.ZERO if (bash_flick_candidate or side_kick_flick_candidate)" in change
assert "FLICK_DIRECTION_POLICY.within_sector(" in change
assert "displacement, gesture_screen_forward" in change
print("PASS: screen-space RUN/BOOST/STEP and SERA-relative Bash are preserved")

# Match FlickDirectionPolicy.sector_index(): rotate clockwise from projected actor forward.
def sector(dx, dy, fx, fy):
    right_x, right_y = -fy, fx
    angle = math.atan2(dx*right_x + dy*right_y, dx*fx + dy*fy)
    return math.floor((angle+math.pi/4)/(math.pi/2)) % 4

# Actor faces top, right, bottom or left of screen: right kick is always
# relative to actor, NOT tied to screen RIGHT. Verify the 90-degree wedges.
for fx,fy in ((0,-1),(1,0),(0,1),(-1,0)):
    right=(-fy,fx)
    left=(fy,-fx)
    assert sector(*right,fx,fy)==1
    assert sector(*left,fx,fy)==3
    assert sector(fx,fy,fx,fy)==0
    assert sector(-fx,-fy,fx,fy)==2
    for degrees in (-44.0,-10.0,10.0,44.0):
        rad=math.radians(degrees)
        x=right[0]*math.cos(rad)-right[1]*math.sin(rad)
        y=right[0]*math.sin(rad)+right[1]*math.cos(rad)
        assert sector(x,y,fx,fy)==1
print("PASS: 90-degree right/left wedges rotate with SERA across four screen facings")
print("SERA v267 actor-facing kick regression PASSED (static/numeric only).")
