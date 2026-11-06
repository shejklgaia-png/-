#!/usr/bin/env python3
"""SERA v109: RUN turn lean sign, limit, release, and source wiring."""
from pathlib import Path
import math
import json

ROOT = Path(__file__).resolve().parents[1]
rig = (ROOT / "scripts/sera_rig.gd").read_text(encoding="utf-8")
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
model = json.loads((ROOT / "assets/sera_source.json").read_text(encoding="utf-8"))

for line in (
    "const RUN_TURN_MAX_LEAN_DEGREES: float = 15.0",
    "const RUN_TURN_RATE_AT_MAX_LEAN: float = 7.0",
    "const RUN_TURN_LEAN_ATTACK_SECONDS: float = 0.06",
    "const RUN_TURN_LEAN_RETURN_SECONDS: float = 0.20",
    "run_turn_previous_direction = _run_heading_from_weights()",
    "var signed_turn: float = (",
    "run_turn_previous_direction.y * heading.x",
    "- run_turn_previous_direction.x * heading.y",
    "desired_lean = RUN_TURN_MAX_LEAN_DEGREES * clampf(",
    "run_turn_lean_degrees = lerpf(run_turn_lean_degrees, desired_lean, alpha)",
    "if uid == RUN_ROOT_BONE_UUID and not is_zero_approx(run_turn_lean_degrees):",
    "var bank_axis: Vector3 = facing * Vector3.BACK",
    "var bank := Quaternion(bank_axis, -deg_to_rad(run_turn_lean_degrees))",
    "blended_rotation = (bank * blended_rotation).normalized()",
):
    assert line in rig, line
assert rig.index("sample_rotation = run_yaw_correction * sample_rotation") < rig.index("var bank := Quaternion")
assert rig.index("blended_rotation = (bank * blended_rotation).normalized()") < rig.index('return {"rotation": blended_rotation')
assert rig.count("var bank := Quaternion(") == 1
assert len(model["animations"]) == 17
assert all(any(a["name"] == n for a in model["animations"]) for n in
           ("run_front_original", "run_back", "run_right", "run_Left"))
assert 'rig.call("set_moving", running, movement_boost_active, local_run_direction)' in main
assert "const STRIKE_DAMAGE = [12, 12, 26]" in main
assert "JUMP_TOUCH_INPUT_ENABLED: bool = false" in main


def signed_rate(old, new, seconds):
    return (old[1] * new[0] - old[0] * new[1]) / seconds

assert signed_rate((0.0, 1.0), (1.0, 0.0), 0.1) > 0  # turn right
assert signed_rate((0.0, 1.0), (-1.0, 0.0), 0.1) < 0 # turn left
assert signed_rate((0.0, 1.0), (0.0, -1.0), 0.1) == 0 # 180° ambiguous
assert signed_rate((1.0, 0.0), (1.0, 0.0), 0.1) == 0

def target_bank(rate):
    return 15.0 * max(-1.0, min(1.0, rate/7.0))

assert target_bank(100) == 15.0
assert target_bank(-100) == -15.0
assert target_bank(0) == 0.0

def ease(start, goal, sec, fps, tau):
    v = start
    for _ in range(round(sec * fps)):
        v = v + (goal - v)*(1-math.exp(-1/fps/tau))
    return v

r30 = ease(15.0, 0.0, .5, 30, .20)
r60 = ease(15.0, 0.0, .5, 60, .20)
assert abs(r30-r60) < 1e-9
assert 0 < r30 < 1.5  # return toward upright
assert 0 < ease(0,15,.1,60,.06) < 15

print("v109 turn banking: right/left sign, current max-angle clamp, smooth return, regressions PASS")
