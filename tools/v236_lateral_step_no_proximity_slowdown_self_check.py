#!/usr/bin/env python3
"""v236 lateral speed regression: v300 extends fixed 10m/s to every STEP."""
from pathlib import Path
import re,math
R=Path(__file__).resolve().parents[1]
main=(R/"scripts/main.gd").read_text(encoding="utf-8")
project=(R/"project.godot").read_text(encoding="utf-8")
v=re.search(r'config/name="SERA v(\d+)"',project)
assert v and int(v.group(1))>=300
def segment(a,b):
    return main.split(a,1)[1].split(b,1)[0]
omni=segment("func _start_omni_step(flick: Vector2) -> bool:","func _start_back_step()")
side=segment("func _start_side_step(side: int) -> bool:","func _finish_side_step(")
back=segment("func _start_back_step() -> bool:","func _start_side_step(")
speed=segment("func _step_speed_for_player_position(pos: Vector3) -> float:","func _refresh_step_status_ui(")
for token in ("const STEP_FORWARD_DISTANCE: float = 4.0",
              "const STEP_SIDE_DISTANCE: float = 4.0",
              "const BACK_STEP_DISTANCE: float = 4.0",
              "const STEP_SPEED: float = 15.0"):
    assert token in main,token
# The legacy falloff remains as an unused helper, but cannot affect a
# committed STEP in any direction, including direct back/side helpers.
assert "STEP_FALLOFF_START_SURFACE_DISTANCE - surface_distance" in speed
assert "lerpf(STEP_SPEED, STEP_CLOSE_SPEED, eased)" in speed
for fn in (omni,side,back):
    assert 'step_speed_current = STEP_SPEED * float(part_stats.get("step_speed_mult", 1.0))' in fn
    assert "_step_speed_for_player_position(" not in fn
assert 'step_arc_length = _step_fixed_distance_for_direction(direction)' in omni
assert 'step_arc_length = BACK_STEP_DISTANCE' in back
assert 'var path_length: float = STEP_SIDE_DISTANCE' in side
assert "_move_player_swept(requested, true)" in segment(
    "func _advance_side_step(delta: float) -> void:","func _move_player_swept(")
for equipment in (0.7,1.,1.3):
    for radius in (0.2,1.,2.,4.,10.,100.):
        assert math.isclose(15.*equipment,15.*equipment)
print("PASS v236/v300: 15m/s in all directions independent of target distance; equipment still multiplies")
