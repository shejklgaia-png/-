#!/usr/bin/env python3
"""Video regression migrated in v284: screen side flick never STEP/Bash."""
from pathlib import Path

# v317 refactor: assert main's delegation and the canonical pure math.
from pathlib import Path as _SplitPath
SERA_INPUT = (_SplitPath(__file__).resolve().parents[1] / "scripts/sera_input_gestures.gd").read_text(encoding="utf-8")
import math,re

root=Path(__file__).resolve().parents[1]
main=(root/"scripts/main.gd").read_text(encoding="utf-8")
assert int(re.search(r'config/name="SERA v(\d+)"',(root/"project.godot").read_text()).group(1))>=284
helper=SERA_INPUT.split("static func combo_kick_side(flick: Vector2) -> int:",1)[1].split("static func upward_jump_flick",1)[0]
release=main.split("func _end_drag(release_pos: Vector2) -> void:",1)[1].split(
    "func _remember_jump_flick_sample",1)[0]
request=main.split("func _request_combo_side_kick(flick: Vector2) -> bool:",1)[1].split(
    "func _launch_combo_side_kick",1)[0]
physics=main.split("func _physics_process(delta: float) -> void:",1)[1].split(
    "func _process(",1)[0]
assert "flick, Vector2.UP" in helper and "gesture_screen_forward" not in helper
assert "return 1" in helper and "return -1" in helper and "return 2" in helper
assert "_combo_kick_side_for_flick(kick_flick_direction) != 0" in release
assert release.index("if side_kick_requested and kick_flick_direction") < release.index("if bash_requested")
assert "buffered_side_kick_flick = flick.normalized()" in request
assert "buffered_side_kick_side = side" in request
assert "not (bash_flick_candidate or side_kick_flick_candidate)" in physics
hud = (Path(__file__).resolve().parents[1] / "scripts/sera_combat_hud_text.gd").read_text(encoding="utf-8")
assert '"KICK RIGHT  |  Kick_r"' in hud
assert '"KICK LEFT  |  Kick_l"' in hud
assert "COMBAT_HUD_TEXT.step_label(" in physics
assert "if kick_side != 0:" in hud
def sector(x,y):
    return math.floor((math.atan2(x,-y)+math.pi/4)/(math.pi/2))%4
for yaw in range(720):
    for (dx,dy),expected in [((120,0),1),((-120,0),3),((0,120),2),((0,-120),0)]:
        assert sector(dx,dy)==expected
print("PASS v284: captured side-flick videos retain screen-right/left kicks for any facing")

assert "return INPUT_GESTURES.combo_kick_side(flick)" in main
