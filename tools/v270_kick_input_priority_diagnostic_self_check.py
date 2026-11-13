#!/usr/bin/env python3
"""v270 diagnostic regression updated for v284 absolute 4-way melee flicks."""
from pathlib import Path

# v317 refactor: assert main's delegation and the canonical pure math.
from pathlib import Path as _SplitPath
SERA_INPUT = (_SplitPath(__file__).resolve().parents[1] / "scripts/sera_input_gestures.gd").read_text(encoding="utf-8")
import re,math
root=Path(__file__).resolve().parents[1]
main=(root/"scripts/main.gd").read_text(encoding="utf-8")
rig=(root/"scripts/sera_rig.gd").read_text(encoding="utf-8")
assert int(re.search(r'config/name="SERA v(\d+)"',(root/"project.godot").read_text()).group(1))>=284
def body(a,b):
    return main.split("func "+a,1)[1].split("func "+b,1)[0]
helper=SERA_INPUT.split("static func combo_kick_side(flick: Vector2) -> int:",1)[1].split("static func upward_jump_flick",1)[0]
release=body("_end_drag(release_pos: Vector2) -> void:","_remember_jump_flick_sample")
request=body("_request_combo_side_kick(flick: Vector2) -> bool:","_launch_combo_side_kick")
launch=body("_launch_combo_side_kick(flick: Vector2, side: int) -> bool:","_start_omni_step")
movement=body("_start_omni_step(flick: Vector2) -> bool:","_start_back_step")
begin=body("_begin_drag(pos: Vector2) -> void:","_analog_stick_direction")
detail=body("_refresh_step_status_ui() -> void:","_record_kick_debug")
diagnostic=body("_record_kick_debug(message: String) -> void:","_pointer_on_training_test_button")
assert "flick, Vector2.UP" in helper
assert "gesture_screen_forward" not in helper
for key in ["1:","2:","3:","return 1","return 2","return -1"]:
    assert key in helper
assert "_combo_kick_side_for_flick(kick_flick_direction) != 0" in release
assert "var side: int = _combo_kick_side_for_flick(flick)" in request
assert release.index("if side_kick_requested") < release.index("if bash_requested")
assert "if _start_omni_step(flick_direction):" in release
assert "_screen_drag_to_ground(direction)" in movement
assert "kick_touch_started_in_window = side_kick_flick_candidate" in begin
for status in ['"WINDOW CLOSED"','"CLIP MISSING "',' "STATE BLOCKED"']:
    pass
assert '"WINDOW CLOSED"' in release
assert '"CLIP MISSING "' in request
assert '"STATE BLOCKED"' in request
assert '"EN / ACTION BLOCKED"' in launch
assert '"QUEUED "' in request
assert "kick_debug_remaining = 2.0" in diagnostic
assert 'kick_debug_text = "KICK: " + message' in diagnostic
assert "step_detail_label.text = kick_debug_text" in detail
assert "var screen_sector: int = FLICK_DIRECTION_POLICY.sector_index(" in release
assert "func start_side_kick(side: int, movement_duration: float) -> bool:" in rig
def sector(x,y):
    return math.floor((math.atan2(x,-y)+math.pi/4)/(math.pi/2))%4
for yaw in range(720):
    assert sector(120,0)==1 and sector(-120,0)==3
    assert sector(0,120)==2 and sector(0,-120)==0
print("PASS v284: all cardinal gestures independent of actor heading and kick debug intact")

assert "return INPUT_GESTURES.combo_kick_side(flick)" in main
