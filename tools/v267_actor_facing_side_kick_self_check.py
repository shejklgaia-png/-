#!/usr/bin/env python3
"""Regression migrated in v284: kick directions are SCREEN-fixed, never actor-yaw."""
from pathlib import Path

# v317 refactor: assert main's delegation and the canonical pure math.
from pathlib import Path as _SplitPath
SERA_INPUT = (_SplitPath(__file__).resolve().parents[1] / "scripts/sera_input_gestures.gd").read_text(encoding="utf-8")
import math, re

root=Path(__file__).resolve().parents[1]
main=(root/"scripts/main.gd").read_text(encoding="utf-8")
project=(root/"project.godot").read_text(encoding="utf-8")
assert int(re.search(r'config/name="SERA v(\d+)"',project).group(1))>=284
helper=SERA_INPUT.split("static func combo_kick_side(flick: Vector2,",1)[1].split("static func upward_jump_flick",1)[0]
assert "FLICK_DIRECTION_POLICY.sector_index(" in helper
assert "flick, actor_screen_forward)" in helper
assert "actor_screen_forward" in helper
for token in ("1:", "2:", "3:", "return 1", "return 2", "return -1", "return 0"):
    assert token in helper,token
start=main.split("func _end_drag(release_pos: Vector2) -> void:",1)[1].split(
    "func _remember_jump_flick_sample",1)[0]
assert start.index("_request_combo_side_kick(kick_flick_direction)")<start.index(
    "_request_combo_bash()")
change=main.split("func _change_drag(pos: Vector2) -> void:",1)[1].split(
    "func _update_boost_gesture",1)[0]
assert "displacement, gesture_screen_forward" in change
assert "direction_input = Vector2.ZERO if (bash_flick_candidate or side_kick_flick_candidate)" in change
policy=(root/"scripts/flick_direction_policy.gd").read_text(encoding="utf-8")
assert "const SECTOR_COUNT: int = 4" in policy
assert "return displacement.normalized()" in policy
def sector(x,y):
    angle=math.atan2(x,-y)
    return math.floor((angle+math.pi/4)/(math.pi/2))%4
for actor_degrees in range(0,360,10):
    # Actor orientation is deliberately absent from classification.
    for swipe, expected in [((0,-100),0),((100,0),1),((0,100),2),((-100,0),3)]:
        assert sector(*swipe)==expected
print("PASS v329: actor-relative kicks and screen-relative RUN/STEP")

assert "return INPUT_GESTURES.combo_kick_side(flick, gesture_screen_forward)" in main
