#!/usr/bin/env python3
"""v148: ground RUN and BOOST move 1.25x; preserve jump, steps and animations."""
from pathlib import Path
import math
import re

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
rig = (root / "scripts/sera_rig.gd").read_text(encoding="utf-8")
project = (root / "project.godot").read_text(encoding="utf-8")
docs = (root / "README_v148_ja.md").read_text(encoding="utf-8")

def number(name):
    match = re.search(r"^const " + re.escape(name) + r": float = ([0-9.]+)", main, re.M)
    assert match, name
    return float(match.group(1))

assert re.findall(r'^config/name="([^"]+)"$', project, re.M) == ["SERA v148"]
assert number("MOVE_SPEED") == 3.25
assert number("GROUND_MOVE_SPEED_SCALE") == 1.25
assert number("MOVEMENT_BOOST_MULTIPLIER") == 1.5
assert number("BOOST_START_RADIUS_RATIO") == 1.25
assert number("BOOST_EXIT_RADIUS_RATIO") == 1.10
assert number("BOOST_CONFIRM_SECONDS") == 0.10
assert number("BOOST_ACCELERATION_SECONDS") == 0.15
assert number("STEP_SPEED") == 10.0
assert number("STEP_CLOSE_SPEED") == 8.0
assert number("MELEE_DASH_SPEED") == 11.5
assert number("BACK_STEP_DISTANCE") == 4.0
assert number("JUMP_AIR_STEER_SPEED_FACTOR") == 0.30

ground = "player.velocity = world_move * MOVE_SPEED * GROUND_MOVE_SPEED_SCALE * boost_speed_multiplier"
air = "steering_velocity = _screen_drag_to_ground(direction_input) * (MOVE_SPEED * JUMP_AIR_STEER_SPEED_FACTOR)"
assert ground in main
assert main.count("GROUND_MOVE_SPEED_SCALE") == 2  # declared and used only on ground
assert air in main
assert "player.move_and_slide()" in main
assert "direction_input = delta.limit_length(1.0)" in main
assert "boost_speed_multiplier = move_toward(boost_speed_multiplier, boost_speed_target," in main
assert "rig.call(\"set_moving\", running, movement_boost_active, local_run_direction)" in main
assert 'const RUN_ANIMATION_SPEED: float = 1.875' in rig
assert "BOOST  x1.5" in main and "RUN  x1.0" in main
assert math.isclose(number("MOVE_SPEED") * number("GROUND_MOVE_SPEED_SCALE"), 4.0625)
assert math.isclose(number("MOVE_SPEED") * number("GROUND_MOVE_SPEED_SCALE") * number("MOVEMENT_BOOST_MULTIPLIER"), 6.09375)
for analog in (0.0, 0.25, 0.5, 0.75, 1.0):
    for boost in (1.0, 1.5):
        old = number("MOVE_SPEED") * analog * boost
        new = old * number("GROUND_MOVE_SPEED_SCALE")
        assert math.isclose(new, old * 1.25, abs_tol=1e-12)
assert "4.0625 m/s" in docs and "6.09375 m/s" in docs
print("v148 ground RUN / BOOST 1.25x speed: STATIC + MATH PASS")
print("Godot/Android runtime speed: NOT TESTED")
