#!/usr/bin/env python3
"""SERA v236: remove target-proximity slowdowns from lateral STEPs only."""
from __future__ import annotations
from pathlib import Path
import math
import re

root = Path(__file__).resolve().parents[1]
main = (root / "scripts/main.gd").read_text(encoding="utf-8")
proj = (root / "project.godot").read_text(encoding="utf-8")
version = re.search(r'^config/name="SERA v(\d+)"$', proj, re.M)
assert version and int(version.group(1)) >= 236

def func(name: str, until: str) -> str:
    return main.split(name, 1)[1].split(until, 1)[0]

omni = func("func _start_omni_step(flick: Vector2) -> bool:",
            "func _start_back_step()")
side = func("func _start_side_step(side: int) -> bool:",
            "func _finish_side_step(")
back = func("func _start_back_step() -> bool:",
            "func _start_side_step(")
speed = func("func _step_speed_for_player_position(pos: Vector3) -> float:",
             "func _refresh_step_status_ui()")
hud = func("func _refresh_step_status_ui() -> void:",
            "func _pointer_on_training_test_button(")

assert "const STEP_SPEED: float = 10.0" in main
assert "const STEP_CLOSE_SPEED: float = 8.0" in main
assert "const STEP_CLOSE_SURFACE_DISTANCE: float = 2.0" in main
assert "const STEP_FALLOFF_START_SURFACE_DISTANCE: float = 5.0" in main
assert "const STEP_FORWARD_DISTANCE: float = 3.0" in main
assert "const BACK_STEP_DISTANCE: float = 4.0" in main
assert "STEP_FALLOFF_START_SURFACE_DISTANCE - surface_distance" in speed
assert "lerpf(STEP_SPEED, STEP_CLOSE_SPEED, eased)" in speed
assert "var radial_speed: float = _step_speed_for_player_position(player.position)" in omni
assert 'var lateral_speed: float = STEP_SPEED * float(part_stats.get("step_speed_mult", 1.0))' in omni
assert "step_speed_current = lerpf(radial_speed, lateral_speed, absf(direction.x))" in omni
assert 'step_speed_current = STEP_SPEED * float(part_stats.get("step_speed_mult", 1.0))' in side
assert "step_speed_current = _step_speed_for_player_position(player.position)" in back
assert "step_radial_delta = direction.y * radial_distance" in omni
assert "BACK_STEP_DISTANCE if direction.y >= 0.0 else STEP_FORWARD_DISTANCE" in omni
assert "maxf(STEP_MIN_ARC_LENGTH, radius * deg_to_rad(STEP_ORBIT_ANGLE_DEGREES))" in omni
assert "STEP_MIN_ARC_LENGTH, STEP_MAX_ARC_LENGTH)" in omni
assert "_move_player_swept(requested, true)" in func(
    "func _advance_side_step(delta: float) -> void:", "func _move_player_swept(")
assert 'display_speed = STEP_SPEED * float(part_stats.get("step_speed_mult", 1.0))' in hud
assert '"STEP SPEED %.1fm/s" % (' in main

# Numeric mirror of the current 5->2m radial speed interpolation.
def radial_speed(surface_distance: float) -> float:
    f = max(0.0, min(1.0, (5.0 - surface_distance) / 3.0))
    smooth = f*f*(3.0 - 2.0*f)
    return 10.0 + (8.0 - 10.0)*smooth

def mixed_speed(surface_distance: float, x: float, equipment_mult: float = 1.0) -> float:
    base = radial_speed(surface_distance)
    return (base*(1.0-abs(x)) + 10.0*abs(x))*equipment_mult

for d in (0.0, 1.0, 2.0, 2.5, 3.5, 4.25, 5.0, 8.0, 100.0):
    for equip in (0.8, 1.0, 1.2):
        assert math.isclose(mixed_speed(d, 1.0, equip), 10.0*equip)
        assert math.isclose(mixed_speed(d, -1.0, equip), 10.0*equip)
        assert math.isclose(mixed_speed(d, 0.0, equip), radial_speed(d)*equip)
        # All diagonals interpolate smoothly, never exceed their endpoint speeds.
        for xx in (0.1, 0.25, 0.5, math.sqrt(0.5), 0.9):
            v = mixed_speed(d, xx, equip)
            assert radial_speed(d)*equip-1e-8 <= v <= 10.0*equip+1e-8
            assert math.isclose(v, mixed_speed(d, -xx, equip))
assert math.isclose(radial_speed(1.0), 8.0)
assert math.isclose(radial_speed(3.5), 9.0)
assert math.isclose(radial_speed(6.0), 10.0)
print("PASS v236: lateral STEP always equipment-adjusted 10m/s at any enemy distance")
print("PASS v236: original forward/back slowdown and 360-degree diagonal continuity")
print("PASS v236: original step orbit, collision, distance bounds and HUD semantics")
print("Android/Godot runtime not verified")
