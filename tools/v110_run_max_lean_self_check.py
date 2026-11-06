#!/usr/bin/env python3
"""v110: maximum RUN banking angle is 15 degrees; timing and gameplay unchanged."""
from pathlib import Path
import math
ROOT = Path(__file__).resolve().parents[1]
rig = (ROOT / "scripts/sera_rig.gd").read_text(encoding="utf-8")
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
project = (ROOT / "project.godot").read_text(encoding="utf-8")
assert "const RUN_TURN_MAX_LEAN_DEGREES: float = 15.0" in rig
assert "const RUN_TURN_RATE_AT_MAX_LEAN: float = 7.0" in rig
assert "const RUN_TURN_LEAN_ATTACK_SECONDS: float = 0.06" in rig
assert "const RUN_TURN_LEAN_RETURN_SECONDS: float = 0.20" in rig
assert "const RUN_DIRECTION_BLEND_SECONDS: float = 0.12" in rig
assert "desired_lean = RUN_TURN_MAX_LEAN_DEGREES * clampf(" in rig
assert "var bank := Quaternion(Vector3.BACK, -deg_to_rad(run_turn_lean_degrees))" in rig
assert 'rig.call("set_moving", running, movement_boost_active, local_run_direction)' in main
assert "const STRIKE_DAMAGE = [12, 12, 26]" in main
assert 'config/name="SERA v110 | RUN Turn Bank 15deg"' in project
def bank(rate):
    return 15.0 * max(-1.0, min(1.0, rate / 7.0))
assert bank(0) == 0.0
assert bank(7.0) == 15.0
assert bank(-7.0) == -15.0
assert bank(100.0) == 15.0
assert bank(-100.0) == -15.0
print("v110 15-degree RUN banking with unchanged turn response: PASS")
