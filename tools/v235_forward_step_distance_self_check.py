#!/usr/bin/env python3
"""SERA v235: forward STEP moves 3m (1.5x), without changing other axes."""
from pathlib import Path
import math
import re

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
project = (ROOT / "project.godot").read_text(encoding="utf-8")
version = re.search(r'^config/name="SERA v(\d+)"$', project, re.M)
assert version and int(version.group(1)) >= 235

assert "const STEP_MIN_ARC_LENGTH: float = 2.0" in main
assert "const STEP_FORWARD_DISTANCE: float = 3.0" in main
assert "const BACK_STEP_DISTANCE: float = 4.0" in main
assert "const STEP_MAX_ARC_LENGTH: float = 4.0" in main
assert "const STEP_SPEED: float = 10.0" in main
assert "const STEP_CLOSE_SPEED: float = 8.0" in main

step = main.split("func _start_omni_step(flick: Vector2) -> bool:", 1)[1].split(
    "func _start_back_step()", 1)[0]
assert "var direction: Vector2 = flick.normalized()" in step
assert "var back_mix: float = smoothstep(-0.25, 0.25, direction.y)" in step
assert "STEP_FORWARD_DISTANCE, BACK_STEP_DISTANCE, back_mix)" in step
assert "step_radial_delta = direction.y * radial_distance" in step
assert "var tangent_distance: float = absf(direction.x) * side_length" in step
assert "sqrt(tangent_distance * tangent_distance + step_radial_delta * step_radial_delta)" in step
assert "STEP_MIN_ARC_LENGTH, STEP_MAX_ARC_LENGTH)" in step
assert "step_duration_current = (step_arc_length / step_speed_current" in step
assert 'rig.call("start_omni_step", pose_direction)' in step

advance = main.split("func _advance_side_step(delta: float) -> void:", 1)[1].split(
    "func _move_player_swept(", 1)[0]
assert "initial_radius + step_radial_delta * travel_progress" in advance
assert "if side_kick_active else progress)" in advance
assert "_move_player_swept(requested, true)" in advance

# Mirror the four cardinal directional plans with a 6m target radius.
radius = 6.0
side_length = min(max(2.0, radius * math.radians(35)), min(4.0, 10.0 * 0.40))
def plan(x: float, y: float) -> tuple[float, float]:
    t=max(0.,min(1.,(y+.25)/.5))
    t=t*t*(3.-2.*t)
    radial = y * (3.0+t)
    planned = min(4.0, max(2.0, math.hypot(abs(x) * side_length, radial)))
    return radial, planned

assert plan(0.0, -1.0) == (-3.0, 3.0), plan(0.0, -1.0)
assert plan(0.0, 1.0) == (4.0, 4.0), plan(0.0, 1.0)
assert math.isclose(plan(1.0, 0.0)[1], side_length)
assert math.isclose(plan(-1.0, 0.0)[1], side_length)
for speed in (8.0, 9.0, 10.0):
    duration = 3.0 / speed
    assert 0.30 - 1e-9 <= duration <= 0.375 + 1e-9
    assert duration < 0.40
    assert math.isclose(duration * speed, 3.0)
# A forward-diagonal flick must still have an increased forward radial component.
x, y = math.sqrt(0.5), -math.sqrt(0.5)
assert math.isclose(plan(x, y)[0], -3.0 * math.sqrt(0.5))
assert "const JUMP_TOUCH_INPUT_ENABLED: bool = false" in main

print("PASS v235: forward STEP 2m -> 3m (x1.5), 8-10m/s unchanged")
print("PASS v235: lateral/backward and 360-degree input, swept collision preserved")
print("Android/Godot runtime not verified")
