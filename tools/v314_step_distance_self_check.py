#!/usr/bin/env python3
"""v314: every ordinary 360-degree flick STEP is fixed 5m; BOOST uncapped."""
from pathlib import Path
import math,re
from sera_active_contracts import load_active_specs, main_float_constant
root=Path(__file__).resolve().parents[1]
main=(root/"scripts/main.gd").read_text(encoding="utf-8")
project=(root/"project.godot").read_text(encoding="utf-8")
assert int(re.search(r'config/name="SERA v(\d+)"',project).group(1))>=314
spec = load_active_specs()
distance, speed = spec["ordinary_step"]["distance_m"], spec["ordinary_step"]["speed_mps"]
for key in ("BACK_STEP_DISTANCE","STEP_FORWARD_DISTANCE","STEP_SIDE_DISTANCE",
            "STEP_MIN_ARC_LENGTH","STEP_MAX_ARC_LENGTH"):
    assert main_float_constant(main, key) == distance,key
assert main_float_constant(main, "STEP_SPEED") == speed
assert main_float_constant(main, "SIDE_KICK_BOOST_DISTANCE") == spec["side_kick"]["distance_m"]
assert main_float_constant(main, "SIDE_KICK_STEP_SPEED") == spec["side_kick"]["speed_mps"]
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
assert 0 < distance / speed <= main_float_constant(main, "STEP_MAX_DURATION")
print("V314_360_STEP_FIXED_5M_STATIC_PASS")
