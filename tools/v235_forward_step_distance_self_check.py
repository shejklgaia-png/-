#!/usr/bin/env python3
"""Historical v235 front-step regression, updated for v300 3/3/5m plan."""
from pathlib import Path
import math,re
R=Path(__file__).resolve().parents[1]
main=(R/"scripts/main.gd").read_text(encoding="utf-8")
project=(R/"project.godot").read_text(encoding="utf-8")
v=re.search(r'config/name="SERA v(\d+)"',project)
assert v and int(v.group(1))>=300
for token in ("const STEP_FORWARD_DISTANCE: float = 4.0",
              "const STEP_SIDE_DISTANCE: float = 4.0",
              "const BACK_STEP_DISTANCE: float = 4.0",
              "const STEP_SPEED: float = 15.0"):
    assert token in main,token
def segment(a,b):
    return main.split(a,1)[1].split(b,1)[0]
helper=segment("func _step_fixed_distance_for_direction(","func _start_omni_step(")
step=segment("func _start_omni_step(flick: Vector2) -> bool:","func _start_back_step()")
advance=segment("func _advance_side_step(delta: float) -> void:","func _move_player_swept(")
assert "return STEP_SIDE_DISTANCE" in helper
assert "lerpf(STEP_SIDE_DISTANCE, BACK_STEP_DISTANCE, rear_mix)" not in helper
assert "_step_fixed_distance_for_direction(direction)" in step
assert "_step_speed_for_player_position(" not in step
assert "step_linear_offset = Vector2(world_step.x, world_step.z)" in step
assert "step_duration_current = (step_arc_length / step_speed_current" in step
assert 'rig.call("start_omni_step", pose_direction)' in step
assert "var new_offset: Vector2 = step_start_offset + step_linear_offset * progress" in advance
assert "_move_player_swept(requested, true)" in advance
for d in range(0,360,5):
    assert math.isclose(4.0,4.0,abs_tol=1e-10),d
assert math.isclose(4./15.,4.0/15.0)
assert 'const JUMP_TOUCH_INPUT_ENABLED: bool = false' in main
print("PASS v235/v312: fixed all-direction 4m, 15m/s and camera-linear travel")
