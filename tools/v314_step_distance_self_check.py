#!/usr/bin/env python3
"""v314: every ordinary 360-degree flick STEP is fixed 5m; BOOST uncapped."""
from pathlib import Path
import math,re
root=Path(__file__).resolve().parents[1]
main=(root/"scripts/main.gd").read_text(encoding="utf-8")
project=(root/"project.godot").read_text(encoding="utf-8")
assert int(re.search(r'config/name="SERA v(\d+)"',project).group(1))>=314
for key in ("BACK_STEP_DISTANCE","STEP_FORWARD_DISTANCE","STEP_SIDE_DISTANCE",
            "STEP_MIN_ARC_LENGTH","STEP_MAX_ARC_LENGTH"):
    assert f"const {key}: float = 5.0" in main,key
assert "const STEP_SPEED: float = 15.0" in main
assert "const SIDE_KICK_BOOST_DISTANCE: float = 3.0" in main
assert "const SIDE_KICK_STEP_SPEED: float = 10.0" in main
assert "const BACK_SOMERSAULT_DISTANCE: float = 5.0" in main
assert "BOOST_TRAVEL_DISTANCE" not in main
assert "boost_distance_capped" not in main
step=main.split("func _start_omni_step(flick: Vector2) -> bool:",1)[1].split("func _start_back_step()",1)[0]
for token in (
    "step_arc_length = _step_fixed_distance_for_direction(direction)",
    "world_step = world_step.normalized() * step_arc_length",
    "step_linear_offset = Vector2(world_step.x, world_step.z)",
    "step_duration_current = (step_arc_length / step_speed_current",
    'step_speed_current = STEP_SPEED * float(part_stats.get("step_speed_mult", 1.0))',
    "step_arc_length = SIDE_KICK_BOOST_DISTANCE",
):
    assert token in step,token
assert "_step_speed_for_player_position(" not in step
assert "return STEP_SIDE_DISTANCE" in main.split("func _step_fixed_distance_for_direction(",1)[1].split("func _start_omni_step(",1)[0]
assert math.isclose(5.0/15.0,1.0/3.0,abs_tol=1e-10)
print("V314_360_STEP_FIXED_5M_STATIC_PASS")
